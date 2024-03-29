# 相同带宽的非正交重叠信道解码

## Methods

1. 自下而上扫描窗口内的信号，目标 chirp 峰值应该是连续的线性增长。

2. 首先对整个目标窗口做 de-chirp，得到候选峰，滑动窗口自左向右，做差值剔除掉各个非正交的候选峰。

3. 对整个窗口做 de-chirp，得到候选峰，滤掉其它信道，再做 de-chirp，对候选峰能量进筛选。

4. 对重叠部分的窗口和非重叠部分的窗口滤波，De-chirp 后取 Bin 值的交集。

5. 滑动窗口中不同 Bin 值对应的能量方差。



## 实验设计

> **Channel 1**：
>
> - 中心频率：433.46875 MHz
> 
>**Channel 2**：
> 
>- 中心频率：433.5 MHz
> 
> **Channel 3**：
>
> - 中心频率：433.53125 MHz

![NogChannel](Figure/NogChannel.png)

### Payload

1. 实验发送的数据：helloworldloraexp

   - Channel 1 Bin 值：[810, 1010, 386, 614, 850, 406, 126, 1022, 367, 677, 347, 284, 27, 551, 991, 990, 49, 827, 822, 85, 265, 587, 421]

   - Channel 2 Bin 值：[810, 1010, 386, 614, 850, 406, 126, 1022, 367, 677, 347, 284, 27, 551, 991, 990, 49, 827, 822, 85, 265, 587, 421]
   - Channel 3 Bin 值：[810, 1010, 386, 614, 850, 406, 126, 1022, 367, 677, 347, 284, 27, 551, 991, 990, 49, 827, 822, 85, 265, 587, 421]

### 文件目录

- 虚拟机共享文件夹：\\192.168.3.102\e\share\samples\
- Channel 1/2/3无时间偏移：\\192.168.3.102\e\data\nodelay_231219\
- Channel 1/2/3：\\192.168.3.102\e\data\ChNum_3_l1m2h3\

### Payload Detection

1. CIC 方法：先检测 SFD，根据 SFD 位置检测前面的 preamble（低信噪比下检测是否会出问题）
2. 

### 实验记录

CIC 解码结果：

 CH1 payload1: 失败（该信道能量较低，可能被直接滤掉了）

 CH2 payload1: [810 722 386 614 850 593 126 1022 842 677 347 862 581 551 574 113 806 827 822 85 421 587 421]

 CH3 payload2: [810 1010 386 614 850 406 126 1022 367 677 347 284 27 551 1004 1006 49 836 822 85 265 587 421]

准确率：0/23 14/23 20/23  

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

6. - **问题**：互相关性能否用在 SFD 的检测中？
   - **答**：参考 CIC 方法

7. - **问题**：由于信号是含正负方向的，滤波器无法滤掉指定的频率
   - **答**：将信号乘上  $e^{j 2\pi t f_s}$ 其中 $f_s$ 是偏移的频率，之后再进行滤波。

8. - **问题**：连续线性变化计算开销大，是否可以从频率角度直接考虑两个窗口的交集
   - **答**：对重叠部分的窗口和非重叠部分的窗口滤波，De-chirp 后取 Bin 值的交集。

9. - **问题**：切分的滑动窗口，de-chirp 结果存在峰值偏移的问题
   - **答**：是否可以通过设置置信区间解决该问题

10. - **问题**：（240112 量哥）可以用三种 downchirp：1.只在信道 1 未重叠部分的 downchirp；2. 只在信道2未重叠的 downchirp； 3. 只在信道 1 和信道 2 重叠部分的 downchirp
    - **答**： 不可行；过滤掉频谱的

11. 重要：*网关侧采集不同设备发送的 payload 会产生不同的 CFO/FFO，非正交重叠信道本质上就是频率偏移。*
    - CH1-2-3 CIC 解：能解出 CH2-3，CH1 因为能量较低被过滤
    - CH2-3-1 CIC 解：能解出 CH2-3，CH1 检测不到

12. 增加少些信道资源，能指数级增加吞吐量

13. 非周期性截断导致频谱泄露，可通过加窗的方式缓解

14. 即使分离不同信道信号，同信道信号解码仍有很大难度

15. - **问题**：

    - **答**： 



> **我的方法**
> 
> 文件 1 检测到 3 个信号 •准确率: 88.4058%
> 文件 2 检测到 4 个信号 •准确率: 88.0435%
> 文件 3 检测到 4 个信号 •准确率: 91.3043%
> 文件 4 检测到 2 个信号 •准确率: 97.8261%
> 文件 5 检测到 4 个信号 •准确率: 92.3913%
> 文件 6 检测到 4 个信号 •准确率: 86.9565%
> 文件 7 检测到 2 个信号 •准确率: 97.8261%
> 文件 8 出现错误
> 文件 9 检测到 3 个信号 •准确率: 91.3043%
> 文件 10 检测到 4 个信号 •准确率: 83.6957%
> 文件 11 未检测到信号
> 文件 12 检测到 3 个信号 •准确率: 88.4058%
> 文件 13 检测到 3 个信号 •准确率: 89.8551%
> 文件 14 未检测到信号
> 文件 15 检测到 4 个信号 •准确率: 89.1304%
> 文件 16 未检测到信号
> 文件 17 出现错误
> 文件 18 检测到 4 个信号 •准确率: 84.7826%
> 文件 19 未检测到信号
> 文件 20 检测到 3 个信号 •准确率: 91.3043%
> 文件 21 未检测到信号
> 文件 22  出现错误
> 文件 23 未检测到信号
> 文件 24 未检测到信号
> 文件 25 检测到 3 个信号 •准确率: 94.2029%
> 文件 26 检测到 3 个信号 •准确率: 89.8551%
> 文件 27 未检测到信号
> 文件 28 检测到 3 个信号 •准确率: 89.8551%
> 文件 29 未检测到信号
> 文件 30 检测到 2 个信号 •准确率: 6.5217%
> 文件 31 未检测到信号
> 文件 32 未检测到信号
> 文件 33 检测到 2 个信号 •准确率: 86.9565%
> 文件 34 未检测到信号
> 文件 35 检测到 2 个信号 •准确率: 97.8261%
> 文件 36 未检测到信号
> 文件 37 出现错误
> 文件 38 未检测到信号
> 文件 39 检测到 3 个信号 •准确率: 89.8551%
> 文件 40 检测到 3 个信号 •准确率: 89.8551%
> 综合准确率: 86.6436%
> 历时 455.027922 秒。

>**我的方法**+滤波
>
>文件 1 检测到 3 个信号 •准确率: 95.6522%
>文件 2 检测到 4 个信号 •准确率: 98.913%
>文件 3 检测到 4 个信号 •准确率: 95.6522%
>文件 4 检测到 2 个信号 •准确率: 93.4783%
>文件 5 检测到 4 个信号 •准确率: 96.7391%
>文件 6 检测到 4 个信号 •准确率: 96.7391%
>文件 7 检测到 2 个信号 •准确率: 97.8261%
>文件 8 出现错误
>文件 9 检测到 3 个信号 •准确率: 94.2029%
>文件 10 检测到 4 个信号 •准确率: 94.5652%
>文件 11 未检测到信号
>文件 12 检测到 3 个信号 •准确率: 92.7536%
>文件 13 检测到 3 个信号 •准确率: 95.6522%
>文件 14 未检测到信号
>文件 15 检测到 4 个信号 •准确率: 95.6522%
>文件 16 未检测到信号
>文件 17 出现错误
>文件 18 检测到 4 个信号 •准确率: 93.4783%
>文件 19 未检测到信号
>文件 20 检测到 3 个信号 •准确率: 95.6522%
>文件 21 未检测到信号
>文件 22 出现错误
>文件 23 未检测到信号
>文件 24 未检测到信号
>文件 25 检测到 3 个信号 •准确率: 92.7536%
>文件 26 检测到 3 个信号 •准确率: 97.1014%
>文件 27 未检测到信号
>文件 28 检测到 3 个信号 •准确率: 97.1014%
>文件 29 未检测到信号
>文件 30 检测到 2 个信号 •准确率: 26.087%
>文件 31 未检测到信号
>文件 32 未检测到信号
>文件 33 检测到 2 个信号 •准确率: 86.9565%
>文件 34 未检测到信号
>文件 35 检测到 2 个信号 •准确率: 93.4783%
>文件 36 未检测到信号
>文件 37 出现错误
>文件 38 未检测到信号
>文件 39 检测到 3 个信号 •准确率: 94.2029%
>文件 40 检测到 3 个信号 •准确率: 91.3043%
>综合准确率: 91.6337%
>
>历时 529.875234 秒。

> **CIC**
>
> 文件 1 检测到 3 个信号 •准确率: 59.4203%
> 文件 2 检测到 3 个信号 •准确率: 68.1159%
> 文件 3 检测到 4 个信号 •准确率: 67.3913%
> 文件 4 检测到 2 个信号 •准确率: 63.0435%
> 文件 5 检测到 3 个信号 •准确率: 76.8116%
> 文件 6 检测到 3 个信号 •准确率: 63.7681%
> 文件 7 检测到 2 个信号 •准确率: 69.5652%
> 文件 8 出现错误
> 文件 8 检测到 2 个信号 •准确率: 69.5652%
> 文件 9 检测到 3 个信号 •准确率: 53.6232%
> 文件 10 检测到 2 个信号 •准确率: 69.5652%
> 文件 11 出现错误
> 文件 11 检测到 2 个信号 •准确率: 69.5652%
> 文件 12 检测到 3 个信号 •准确率: 66.6667%
> 文件 13 检测到 2 个信号 •准确率: 65.2174%
> 文件 14 出现错误
> 文件 14 检测到 2 个信号 •准确率: 65.2174%
> 文件 15 检测到 3 个信号 •准确率: 65.2174%
> 文件 16 出现错误
> 文件 16 检测到 3 个信号 •准确率: 65.2174%
> 文件 17 出现错误
> 文件 17 检测到 3 个信号 •准确率: 65.2174%
> 文件 18 检测到 2 个信号 •准确率: 52.1739%
> 文件 19 未检测到信号
> 文件 20 检测到 3 个信号 •准确率: 79.7101%
> 文件 21 出现错误
> 文件 21 检测到 3 个信号 •准确率: 79.7101%
> 文件 22 出现错误
> 文件 22 检测到 3 个信号 •准确率: 79.7101%
> 文件 23 未检测到信号
> 文件 24 未检测到信号
> 文件 25 检测到 2 个信号 •准确率: 76.087%
> 文件 26 检测到 3 个信号 •准确率: 68.1159%
> 文件 27 出现错误
> 文件 27 检测到 3 个信号 •准确率: 68.1159%
> 文件 28 检测到 3 个信号 •准确率: 78.2609%
> 文件 29 出现错误
> 文件 29 检测到 3 个信号 •准确率: 78.2609%
> 文件 30 出现错误
> 文件 30 检测到 3 个信号 •准确率: 78.2609%
> 文件 31 出现错误
> 文件 31 检测到 3 个信号 •准确率: 78.2609%
> 文件 32 出现错误
> 文件 32 检测到 3 个信号 •准确率: 78.2609%
> 文件 33 检测到 3 个信号 •准确率: 81.1594%
> 文件 34 出现错误
> 文件 34 检测到 3 个信号 •准确率: 81.1594%
> 文件 35 检测到 3 个信号 •准确率: 78.2609%
> 文件 36 出现错误
> 文件 36 检测到 3 个信号 •准确率: 78.2609%
> 文件 37 出现错误
> 文件 37 检测到 3 个信号 •准确率: 78.2609%
> 文件 38 出现错误
> 文件 38 检测到 3 个信号 •准确率: 78.2609%
> 文件 39 检测到 3 个信号 •准确率: 65.2174%
> 文件 40 检测到 2 个信号 •准确率: 65.2174%
> 综合准确率: 70.9166%
> 历时 557.546421 秒。
