classdef LoraDecoder
    properties
        loraSet;
        idealUpchirp;
        idealDownchirp;
        cfoUpchirp;
        cfoDownchirp;
        cfo;
        winOffset;
    end

    methods
        function obj = LoraDecoder(loraSet)
            obj.loraSet = loraSet;
            obj = obj.buildIdealchirp(0);  % default 0 125e3/4
        end

        function obj = buildIdealchirp(obj, f_temp)
            cmx = 1+1*1i;
            pre_dir = 2*pi;
            f0 = f_temp+obj.loraSet.bw/2;                           % 设置理想upchirp和downchirp的初始频率
            f1 = -f_temp+obj.loraSet.bw/2;
            d_symbols_per_second = obj.loraSet.bw / obj.loraSet.fft_x;
            T = -0.5 * obj.loraSet.bw * d_symbols_per_second;
            d_samples_per_second = obj.loraSet.sample_rate;        % sdr-rtl的采样率
            d_dt = 1/d_samples_per_second;         % 采样点间间隔的时间
            t = d_dt*(0:1:obj.loraSet.dine-1);
            % 计算理想downchirp和upchirp存入d_downchirp和d_upchirp数组中（复数形式）
            obj.idealDownchirp = cmx * (cos(pre_dir .* t .* (f0 + T * t)) + sin(pre_dir .* t .* (f0 + T * t))*1i);
            obj.idealUpchirp = cmx * (cos(pre_dir .* t .* (f1 + T * t) * -1) + sin(pre_dir .* t .* (f1 + T * t) * -1)*1i);
        end

        function obj = rebuildIdealchirpCfo(obj, f_temp)
            cmx = 1+1*1i;
            pre_dir = 2*pi;
            d_symbols_per_second = obj.loraSet.bw / obj.loraSet.fft_x;
            T = -0.5 * obj.loraSet.bw * d_symbols_per_second;
            d_samples_per_second = obj.loraSet.sample_rate;       % sdr-rtl的采样率
            d_dt = 1/d_samples_per_second;         % 采样点间间隔的时间
            t = d_dt*(0:1:obj.loraSet.dine-1);
            f0 = f_temp+obj.loraSet.bw/2+obj.cfo;                           % 设置理想upchirp和downchirp的初始频率
            f1 = -f_temp+obj.loraSet.bw/2-obj.cfo;

            % 计算理想downchirp和upchirp存入d_downchirp和d_upchirp数组中（复数形式）
            obj.cfoDownchirp = cmx * (cos(pre_dir .* t .* (f0 + T * t)) + sin(pre_dir .* t .* (f0 + T * t))*1i);
            obj.cfoUpchirp = cmx * (cos(pre_dir .* t .* (f1 + T * t) * -1) + sin(pre_dir .* t .* (f1 + T * t) * -1)*1i);
        end

        % 利用 Preamble(Base-upchirp) 和 SFD(Base-downchirp) 相反偏移的性质，计算 CFO 和 winoffset
        function obj = getcfoWinoff(obj)
            % 计算主峰的 CFO (需要补零操作, 为了更好地评估峰值频率，可以通过用零填充原始信号来增加分析窗的长度。这种方法以更精确的频率分辨率自动对信号的傅里叶变换进行插值)
            % 对 Preamble 阶段的 FFT 峰值进行排序，得到前 filter 的峰
            zeropadding_size = obj.loraSet.factor;                   % 设置补零的数量，这里的 decim 表示，补上 decim-1 倍窗口的零，计算 FFT 时一共是 decim 倍的窗口（decim+1）, e.g. 16
            d_sf = obj.loraSet.sf;
            d_bw = obj.loraSet.bw;
            dine = obj.loraSet.dine;
            fft_x = obj.loraSet.fft_x;
            Preamble_num = obj.loraSet.Preamble_length;
            downchirp = obj.idealDownchirp;
            upchirp = obj.idealUpchirp;
            filter_num = obj.loraSet.filter_num;
            leakage_width1 = obj.loraSet.leakage_width1;    % 0.0050
            leakage_width2 = obj.loraSet.leakage_width2;    % 0.9950
            signal = obj.preambleSignal;
            preambleEndPosTemp = obj.preambleEndPos;

            dine_zeropadding = dine * zeropadding_size * 2 ^ (10 - d_sf);   % e.g. 16384 * 16 * 2 ^ (10 - 10) = 262144
            fft_x_zeropadding = fft_x * zeropadding_size * 2 ^ (10 - d_sf);  % e.g. 1024 * 16 * 2 ^ (10 - 10) = 16384

            % 获取最后一个preamble窗口的若干个峰值，找到最接近preambleBin的峰
            samples = reshape(signal((preambleEndPosTemp - 8) * dine + 1 : preambleEndPosTemp * dine), [dine, Preamble_num]).';  % e.g. 8 * 16384[]
            samples_fft = abs(fft(samples .* downchirp, dine_zeropadding, 2));  %  e.g. 8 * 262144[]
            samples_fft_merge = samples_fft(:, 1 : fft_x_zeropadding) + samples_fft(:, dine_zeropadding - fft_x_zeropadding + 1 : dine_zeropadding);  % e.g. 8 * 16384[]
            [peak, pos] = sort(samples_fft_merge(1 : Preamble_num, :), 2, 'descend');         % 对 FFT 进行排序
            Peak_pos = zeros(size(pos, 1), filter_num);
            Peak_amp = zeros(size(peak, 1), filter_num);
            Peak_pos(:, 1) = pos(:, 1);
            Peak_amp(:, 1) = peak(:, 1);
            for row = 1 : size(pos, 1)
                temp_array = ones(1, size(pos, 2));
                for list = 1 : filter_num
                    temp_array = temp_array & (abs(Peak_pos(row, list) - pos(row, :)) > fft_x_zeropadding * leakage_width1 & abs(Peak_pos(row, list) - pos(row, :)) < fft_x_zeropadding * leakage_width2);
                    temp_num = find(temp_array == 1, 1, 'first');
                    Peak_pos(row, list + 1) = pos(row, temp_num);
                    Peak_amp(row, list + 1) = peak(row, temp_num);
                end
            end

            % 寻找与第一个窗口的峰（默认第一个窗口只有包1的峰）相近的峰，得到与其相近且重复次数最多的 bin，记作 Preamble 的 bin
            if Peak_pos(2) == Peak_pos(1)
                upchirp_ref = Peak_pos(1);
            else
                upchirp_ref = Peak_pos(2);
            end
            upchirp_index = abs(Peak_pos-upchirp_ref) < fft_x_zeropadding*leakage_width1 | abs(Peak_pos-upchirp_ref) > fft_x_zeropadding*leakage_width2;
            upchirp_bin = (Peak_pos(upchirp_index));
            upchirp_peak = mode(upchirp_bin);

            % 已知 SFD downchirp 的位置，得到 SFD downchirp 的 bin
            SFD_samples = signal((preambleEndPosTemp + 3) * dine + 1 : (preambleEndPosTemp + 4) * dine);
            SFD_samples_fft = abs(fft(SFD_samples .* upchirp, dine_zeropadding));
            samples_fft_merge = SFD_samples_fft(1 : fft_x_zeropadding) + SFD_samples_fft(dine_zeropadding - fft_x_zeropadding + 1 : dine_zeropadding);
            [~, downchirp_peak] = max(samples_fft_merge);   % e.g. 2352
        %             figure(1);
        %             FFT_plot(signal((preambleEndPosTemp-8)*dine+1:(preambleEndPosTemp+4)*dine), obj.loraSet, downchirp, 12);
        %             figure(2);
        %             FFT_plot(signal((preambleEndPosTemp-8)*dine+1:(preambleEndPosTemp+4)*dine), obj.loraSet, upchirp, 12);

            % 计算 CFO 和窗口偏移量 (CFO = 2^SF - (preamble bin值 + SFD bin值), 无载波频率偏移时，preamble bin值 + SFD bin值 等于 2^SF)
            if upchirp_peak + downchirp_peak < fft_x_zeropadding*0.5
                cfo_bin = upchirp_peak + downchirp_peak - 2;
                obj.cfo = -cfo_bin/2/fft_x_zeropadding * d_bw;
                obj.winOffset = (downchirp_peak - upchirp_peak) / 2^(11-d_sf);
            elseif upchirp_peak + downchirp_peak > fft_x_zeropadding*1.5
                cfo_bin = upchirp_peak + downchirp_peak - fft_x_zeropadding*2 - 2;
                obj.cfo = -cfo_bin/2/fft_x_zeropadding * d_bw;
                obj.winOffset = (downchirp_peak - upchirp_peak) / 2^(11-d_sf);
            else  % e.g. 13150 + 2352 = 15502
                cfo_bin = upchirp_peak + downchirp_peak - fft_x_zeropadding - 2; % e.g. 15502 - 16384 - 2 = -884
                obj.cfo = -cfo_bin / 2 / fft_x_zeropadding * d_bw;  % e.g. -884 / 2 / 16384 * 125000 = -3.3722e3
                obj.winOffset = (fft_x_zeropadding - (upchirp_peak - downchirp_peak)) / 2 ^ (11 - d_sf);  % e.g. (16384 - (13150 - 2352)) / 2^(11-10) = 5586 / 2 = 2793
            end
            obj.upchirpbin = upchirp_peak;     % e.g. [13150, 13150, 13150, 13150, 13150, 13149, 13149, 13149]
            obj.downchirpbin = downchirp_peak;
        end


        function [signalOut] = signalFrequencyShift(obj, signal, carrirFre)
            Fs = obj.loraSet.sample_rate;
            t = 0:1/Fs:1/Fs*(obj.loraSet.dine-1);
            signalLength = length(signal);
            chirpNum = ceil(signalLength/obj.loraSet.dine);
            m = repmat(exp(1i*2*pi*carrirFre*t), 1, chirpNum);
            signalOut = 2 .* signal .* m;
        end

        function [singalOut] = lowPassFilterFir(obj, signal)
            b = fir1(30, obj.loraSet.pass_arg, "low");
            singalOut = filter(b, 1, signal);
        end

        function [sortedGroups] = findpeaksWithShift(obj, fftResult, fft_x)
            % fft_x = obj.loraSet.fft_x;
            if obj.loraSet.sf == 10
                prominencesThreshold = 0.7;
            elseif obj.loraSet.sf == 9
%                 prominencesThreshold = 0.85;
                prominencesThreshold = 0.6;
            end
            % leakWidth = obj.loraSet.leakage_width1;
%             [peak1, binPos1, ~, prominences1] = findpeaks(fftResult, "MinPeakDistance", fft_x*leakWidth, "SortStr", "descend");
            [peak1, binPos1, ~, prominences1] = findpeaks(fftResult, "SortStr", "descend");
            indecis = find((prominences1./peak1) >= prominencesThreshold);
            peak1 = peak1(indecis);
            binPos1 = binPos1(indecis);
            fftResultShift = circshift(fftResult, [0, fft_x/2]);  % 循环位移一半的窗口
%             [peak2, binPos2, ~, prominences2] = findpeaks(fftResultShift, "MinPeakDistance", fft_x*leakWidth, "SortStr", "descend");
            [peak2, binPos2, ~, prominences2] = findpeaks(fftResultShift, "SortStr", "descend");
            indecis = find((prominences2./peak2) >= prominencesThreshold);
            peak2 = peak2(indecis);
            binPos2 = binPos2(indecis);
            % 先对binPos2进行bin的矫正
            for i = 1:length(binPos2)
                binPos2(i) = binPos2(i) - fft_x/2;
                if binPos2(i) <= 0
                    binPos2(i) = binPos2(i) + fft_x;
                end
            end
            group1 = [peak1; binPos1];
            group2 = [peak2; binPos2];
            % 合并两组数组
            combinedGroups = [group1, group2];

            % 去重每组的第二个数组
            % 使用第二行数据进行去重
            [~, uniqueIndices, ~] = unique(combinedGroups(2, :), 'stable');

            % 提取去重后的数组
            uniqueGroups = combinedGroups(:, uniqueIndices);

            % 按照每组的第一个数组的大小进行排序
            sortedGroups = uniqueGroups;
            % 使用sortrows函数按第一行数据从大到小排序
            sortedGroups = sortrows(sortedGroups.', -1).';
        end
        
    end
end