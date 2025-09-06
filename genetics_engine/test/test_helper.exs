ExUnit.start()

# First load testing_simulator.ex explicitly
Code.require_file("test/support/testing_simulator.ex")

# Then load all other files in test/support recursively
Path.wildcard("test/support/**/*.ex")
|> Enum.filter(fn path -> path != "test/support/testing_simulator.ex" end)
|> Enum.each(&Code.require_file/1)
