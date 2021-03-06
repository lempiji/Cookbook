/++
同期機構/排他処理

マルチスレッドで処理する場合、複数スレッドから同時に同じ変数を読み書きしないようにする必要があります。
これを適切に管理・実現するため、様々な同期処理が必要になる場合があります。

手法については様々な物がありますが、ここではランタイムが持つ同期機構として以下について整理していきます。

- 単独の `synchronized` 文
- `Mutex`
- `ReadWriteMutex`
- `Condition` (TODO)
- `Semaphore` (TODO)
- `Barrier` (TODO)
- `Event` (TODO)
+/
module sync_example;

/++
`synchronized` 文を用いて単独のクリティカルセクションを構成する例です。

主に `std.parallelism` の `parallel` など、複数スレッドから1つの処理が同時に呼び出されるときに利用します。

See_Also: $(LINK https://dlang.org/spec/statement.html#synchronized-statement)
+/
unittest
{
    import std.parallelism : parallel;
    import std.range : iota;

    size_t points;
    foreach (i; iota(10).parallel())
    {
        // synchronized文はそれだけでクリティカルセクションを構成します
        synchronized
        {
            // ここはsynchronized文の中なので、複数スレッドで同時に実行されることはありません
            points += 10;
        }
    }
}

/++
`Mutex` クラスを用いて複数のクリティカルセクションをグループ化し、同期させる例です。

See_Also: https://dlang.org/phobos/core_sync_mutex.html
+/
unittest
{
    import core.thread : Thread;
    import core.sync.mutex : Mutex;

    size_t points;
    auto mutex = new Mutex;

    // 複数のスレッドから points 変数を操作するため、同時実行を防ぐ必要があります。
    // synchronized 文に同じ Mutex オブジェクトを指定することで、排他される範囲をグループ化することができます。
    auto t1 = new Thread({
        synchronized (mutex)
        {
            points += 10;
        }
    });
    auto t2 = new Thread({
        synchronized (mutex)
        {
            points += 20;
        }
    });
    t1.start();
    t2.start();
    t1.join();
    t2.join();

    assert(points == 30);
}

/++
`ReadWriteMutex` クラスを使い、書き込みと読み取りの排他を分けることで効率化する例です。

読み取り同士では排他せず、読み取りと書き込み、書き込み同士のときに排他することで、
単純な `Mutex` による排他よりもスループットが向上することが期待できます。

|          | 読み取り | 書き込み |
|:---------|:--------:|:--------:|
| 読み取り | 排他なし | 排他あり |
| 書き込み | 排他あり | 排他あり |

See_Also: $(LINK https://dlang.org/phobos/core_sync_rwmutex.html)
+/
unittest
{
    import core.thread : ThreadGroup;
    import core.sync.rwmutex : ReadWriteMutex;

    size_t points;
    auto rwMutex = new ReadWriteMutex;

    auto tg = new ThreadGroup;
    tg.create({
        synchronized (rwMutex.reader) // 排他時に読み取り処理であることを明示します
        {
            auto temp = points; // 値を読み取るのみです
        }
    });
    tg.create({
        synchronized (rwMutex.reader) // 排他時に読み取り処理であることを明示します
        {
            auto temp = points; // 値を読み取るのみです
        }
    });
    tg.create({
        synchronized (rwMutex.writer) // 排他時に書き込み処理であることを明示します
        {
            points += 10; // 値を読み書きします
        }
    });
    tg.create({
        synchronized (rwMutex.writer) // 排他時に書き込み処理であることを明示します
        {
            points += 20; // 値を読み書きします
        }
    });
    tg.joinAll();
}

/+
`ReadWriteMutex` クラスで、読み込み(Reader)と書き込み(Writer)の優先度を変更する例です。

`ReadWriteMutex` には `Policy` という設定があり、読み取りと書き込みの処理優先度を切り替えることができます。
これは主にコンストラクタに `ReadWriterMutex.Policy` を渡すことによって切り替えます。

- `Policy.PREFER_READERS` (Reader優先)
    - Writerが処理をした後、Readerが待機していたらReaderを先に処理する
- `Polocy.PREFER_WRITERS` (Writer優先、既定値)
    - Writerが処理をした後、Writerが待機していたらWriterを先に処理する
+/
unittest
{
    import core.sync.rwmutex : ReadWriteMutex;

    // Reader を優先するように初期化します
    auto rwMutex = new ReadWriteMutex(ReadWriteMutex.Policy.PREFER_READERS);
    assert(rwMutex.policy == ReadWriteMutex.Policy.PREFER_READERS);

    // 既定値は Writer が優先されます
    auto t = new ReadWriteMutex;
    assert(t.policy == ReadWriteMutex.Policy.PREFER_WRITERS);
}
