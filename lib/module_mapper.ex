defmodule ModuleMapper do

  def map_lib do
    map_env(Mix.env, "")
  end

  def map_lib(prefix) do
    map_env(Mix.env, prefix)
  end

  def map_env(env, prefix) do
    dir = "_build/#{env |> Atom.to_string}/lib/#{Mix.Project.config |> Keyword.get(:app) |> Atom.to_string}/ebin"
    {:ok, all_files} = File.ls(dir)
    Enum.map(all_files, fn(module) ->
      extract_module_name(module, prefix)
    end)
      |> Enum.reduce(%{}, fn({mod_key, mod}, acc) ->
        Map.put(acc, mod_key, mod)
      end)
  end

  def extract_module_name(module, prefix) do
    frags = String.split(module, ".")
    {gen_name(frags, ""), gen_name(frags, prefix)}
  end

  def gen_name(frags, prefix) do
    List.delete_at(frags, length(frags) - 1)
      |> add_prefix(prefix)
      |> Enum.join(".")
      |> String.to_atom
  end

  def add_prefix(name_list, ""), do: name_list
  def add_prefix(name_list, prefix) do
    last_frag = List.last(name_list)
    List.replace_at(name_list, length(name_list) - 1, "#{prefix}#{last_frag}")
  end
end
