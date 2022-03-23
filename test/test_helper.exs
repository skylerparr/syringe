Code.require_file("test/real_worker.ex")
Code.require_file("test/mock_worker.ex")
Mocker.start_link
ExUnit.start()
