# 相同带宽的非正交重叠信道解码

## Methods

1. 自下而上扫描窗口内的信号，目标 chirp 峰值应该是连续的线性增长。

   - 仿真非正交冲突

     ![NogChirpfft](Figure/Nog_fft.png)

   - 方法仿真验证结果

     ![Methods](Figure/Methods.png)

## 实验设计

> **Channel 1**：
>
> - 中心频率：433.46875 MHz
> - 频带范围：
>
> **Channel 2**：
>
> - 中心频率：433.5 MHz
> - 频带范围：
>
> **Channel 3**：
>
> - 中心频率：433.53125 MHz
> - 频带范围：

![NogChannel](Figure/NogChannel.png)

### Payload

1. 实验发送的数据：helloworldloraexp

   - Channel 1 Bin 值：[810, 1010, 386, 614, 850, 406, 126, 1022, 367, 677, 347, 284, 27, 551, 991, 990, 49, 827, 822, 85, 265, 587, 421]

   - Channel 2 Bin 值：[810, 1010, 386, 614, 850, 406, 126, 1022, 367, 677, 347, 284, 27, 551, 991, 990, 49, 827, 822, 85, 265, 587, 421]
   - Channel 3 Bin 值：[810, 1010, 386, 614, 850, 406, 126, 1022, 367, 677, 347, 284, 27, 551, 991, 990, 49, 827, 822, 85, 265, 587, 421]

### 文件目录

- 虚拟机共享文件夹：\\192.168.3.102\e\share\samples\

- Channel 2 信道无冲突路径：\\192.168.3.102\e\data\channel2_231220\

- Channel 1/3 发送数据时间分别偏移 50/100 ms：\\192.168.3.102\e\data\delay_231219\

- Channel 1/2/3无时间偏移：\\192.168.3.102\e\data\nodelay_231219\

### 实验记录

1. - **问题**：提出一个新的解决方案后，直接通过实验验证难度大，可行性低
   - **答**：编写单 Chirp 信号仿真平台，包括 downchirp、baseupchirp、冲突 chirp 和非正交冲突 chirp 的生成，在此平台上进行方法的可行性验证。
2. - **问题**：实验中发现不同硬件解码的 Bin 值不一致
   - **答**：nf95 由于接口配置问题，在实际使用中不同硬件解码的 Bin 值不一致，改换 Radiolib 库并且在每次 setup 阶段 reset 对应的接口。
3. - **问题**：难以控制不同节点发送数据产生冲突
   - **答**：编写发送端程序，通过 1 个节点控制 3 个节点分别在 Channel 1、2、3 发送数据。
4. - **问题**：实现一控多之后，发现节点几乎同时发送数据
   - **答**：Channel 1 发送数据时间偏移 50 ms，Channel 3发送数据时间偏移 100 ms
5. - **问题**：量哥指出直接进行 3 个非正交信道的解码工作实现难度大
   - **答**：可以先考虑两个非正交信道的解码，例如原信道 Channel 1 占带宽 125 KHz，此时增加 50 KHz 带宽，即可划分两个非正交信道 Channel 1 和 2。即通过增加少量的带宽资源可实现更多信道的划分。
6. - **问题**：
   - **答**：
7. - **问题**：
   - **答**：
8. - **问题**：
   - **答**：
9. - **问题**：
   - **答**：
10. - **问题**：
    - **答**：
11. - **问题**：
    - **答**： 



