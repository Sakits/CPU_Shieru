# CPU Design
## 一些改进
1. ROB 里不存要放进 rd 里的值，只存放指令类型和 rd 位置
2. 
   在 RegFile 里多开 31 个（[31:1]） 32 位寄存器，表示当前寄存器的最新结果（未被 commit）

   优点：
      1. Decoder 不需要再去 ROB 里找值了，时延降低
      2. ROB 中可以存放更少的信息，与 RegFile 里多开消耗的资源几乎抵消
      3. 写起来更方便
3. 每次 Load 加入的时候，遍历一遍 LSB 里的 store，**看看有没有同地址的 store（利用 lowbit 很容易做到），如果有，就相应的设为 READY 或者 WAIT_ROB，就不需要去 MEM 里读了**
   
   **每次 Write 加入的时候，也可以看看有没有同地址的 store（利用 lowbit），如果有，那么那个 store 也可以不存进 MEM 了**
   
   每次找到一个 READY 但没发送过的下标最小（最靠近队头）的 Load 发送给 RS 和 LSB 和 ROB。

   优点：
   1. 让很多 Store 和 Load 都不需要访问内存了
   2. 因为 LSB 里每个位置都有可能是 store，而 store 必然有等待 RS 的接口，当他是 load 的时候，这个接口就被浪费了，但是这么做就可以利用上这个接口
 
   缺点：
   1. 组合逻辑稍微复杂一点点
   
4. 算术指令和比较指令都可能等待寄存器，但他们利用的是不同的单元，一个用加法器一个用比较器，所以每次并行地把 RS 里 READY 的算数指令和比较指令各取一条出来执行，这并不冲突
   优点：
   1. 快

## InstFetch

两位饱和计数器分支预测 BHB

## ICache

普普通通

## Decoder

5 位指令类型 insty （指令类型 37 种，把 Load 和 Store 都只当成一种，load 的 rs2 中放长度，store 的 rd 中放长度，剩 31 种，其中 0 代表无指令）

## RegFile
存两排 32 个 32 位寄存器

其中一排存的是 ROB 中的最新值，这样 ROB 里就不需要存了

## ROB

只存放指令类型和 rd 位置

只存一个 jalr 的最早的那个 pc，因为一定会跳转清空

维护一个循环队列，`front` 和 `rear`，`rear + 1` 可以用 `-(~rear)` 替代*

## RS
算数计算和比较计算并行执行，每次取算数和比较各取一个 ready 的执行

每次使用 lowbit 找到第一个 ready 的数

算术计算：

1 位 flag 表示是否有效

4 位 ROB 索引，表示 RS 需要存入的寄存器对应 ROB 位置 

32 位寄存器的值，表示 RS 需要存入的寄存器的值

比较计算：

1 位 flag 表示是否有效

4 位 ROB 索引，表示 RS 需要存入的寄存器对应 ROB 位置

1 位表示比较的答案

## LSB
每次 Load 加入的时候，遍历一遍 LSB 里的 store，**看看有没有同地址的 store（利用 lowbit 很容易做到），如果有，就相应的设为 READY 或者 WAIT_ROB，就不需要去 MEM 里读了**

   **每次 Write 加入的时候，也可以看看有没有同地址的 store（利用 lowbit），如果有，那么那个 store 也可以不存进 MEM 了**
   
   每次找到一个 READY 但没发送过的下标最小（最靠近队头）的 Load 发送给 RS 和 LSB 和 ROB。

   队头如果发送过就弹出

   Load 也需要 commit 之后再读内存（板子的奇妙特性）
