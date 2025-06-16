defmodule DirectDebug do
  @moduledoc """
  Support module to support synchronous log output for debugging/testing.

  ANSI colour data is based on the information on this page:
  https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
  """

  def ansi_wrap(text, codes) when is_list(codes) do
    "\e[#{Enum.join(codes, ";")}m#{text}\e[0m"
  end

  def bold(text), do: ansi_wrap(text, [1])
  def green(text), do: ansi_wrap(text, [32])
  def red(text), do: ansi_wrap(text, [31])
  def bold_green(text), do: ansi_wrap(text, [1, 32])

  def extra(text, alsoLog? \\ false) do
    if Application.get_env(:gene_prototype_0001, :direct_log_level, :none) in [:all] do
      IO.puts(ansi_wrap("[extra] >> #{text}", [1, 4, 95]))
    end
    if alsoLog? do
      :logger.debug(text)
    end
  end

  def section(text, alsoLog? \\ false) do
    if Application.get_env(:gene_prototype_0001, :direct_log_level, :none) in [:info, :all] do
      IO.puts(ansi_wrap("[--SECTION--] >> #{String.upcase(text)}", [1, 4, 38, 5, 39]))
    end
    if alsoLog? do
      :logger.info(text)
    end
  end

  def info(text, alsoLog? \\ false) do
    if Application.get_env(:gene_prototype_0001, :direct_log_level, :none) in [:info, :all] do
      IO.puts(ansi_wrap("[info] >> #{text}", [1, 4, 32]))
    end
    if alsoLog? do
      :logger.info(text)
    end
  end

  def warning(text, alsoLog? \\ false) do
    if Application.get_env(:gene_prototype_0001, :direct_log_level, :none) in [:warn, :info, :all] do
      IO.puts(ansi_wrap("[warn] >> #{text}", [1, 4, 33]))
      if alsoLog? do
        :logger.warning(text)
      end
    end
  end

  def error(text, alsoLog? \\ false) do
    if Application.get_env(:gene_prototype_0001, :direct_log_level, :none) in [:error, :warn, :info, :all] do
      IO.puts(ansi_wrap("[error] >> #{text}", [1, 4, 31]))
    end
    if alsoLog? do
      :logger.error(text)
    end
  end
end
