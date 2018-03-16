Application.put_env(:ex_job, :default_concurrency, 2)
Application.put_env(:ex_job, :wal_path, ".ex_job.test.wal")
Application.put_env(:ex_job, :wal_file_mod, ExJob.WAL.InMemoryFile)

ExUnit.start()
