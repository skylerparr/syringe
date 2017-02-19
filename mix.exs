defmodule Injector.Mixfile do
  use Mix.Project

  def project do
    [app: :syringe,
     version: "0.10.2",
     elixir: "~> 1.2",
     description: description(),
     package: package(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
    {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    A full library to help inject implementations at build time.
    With this power we can have a strong mocking framework that 
    can also be asynchronous in test.
    """
  end

  defp package do
    [
      name: :syringe,
      files: ["lib", "mix.exs", "README*", "LICENSE*", "config"],
      maintainers: ["Skyler Parr"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/skylerparr/syringe"}
    ]
  end
end
