ExUnit.start()

# Load all files in test/support recursively
Path.wildcard("test/support/**/*.ex")
|> Enum.each(&Code.require_file/1)
