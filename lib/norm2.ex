defmodule Norm2 do
  alias Norm2.Spec

  def spec(tag \\ nil, validator)

  def spec(_tag, %Spec{}=spec), do: spec

  def spec(tag, validator) when is_function(validator) do
    %Spec{tag: tag, validate: validator, coerce: fn x -> x end}
  end

  def spec(tag, %struct{}=data) do
    s = spec(tag, Map.from_struct(data))
    s = all(tag, [s, &is_struct/1, fn x -> x.__struct__ == struct end])
    %{s | coerce: fn x -> struct(struct, s.coerce.(x)) end}
  end

  def spec(tag, map) when is_map(map) do
    %Spec{
      tag: tag,
      validate: fn
        input when is_map(input) ->
          keys = Map.keys(map)
          Enum.all?(keys, fn key ->
            spec = map[key]
            v = Map.get(input, key)
            (v && spec.validate.(v)) || false
          end)

        _x ->
          false
        end,
      coerce: fn
        input when is_map(input) ->
          keys = Map.keys(map)
          Enum.map(keys, fn
            key when is_binary(key) ->
              found? = Map.has_key?(input, key) || Map.has_key?(input, :"#{key}")
              {key, found?, Map.get(input, key) || Map.get(input, :"#{key}")}

            key when is_atom(key) ->
              found? = Map.has_key?(input, key) || Map.has_key?(input, Atom.to_string(key))
              {key, found?, Map.get(input, key) || Map.get(input, Atom.to_string(key))}

            key ->
              {key, Map.has_key?(input, key), Map.get(input, key)}
          end)
          |> Enum.map(fn {key, _found?, v} ->
            spec = map[key]
            {key, spec.coerce.(v)}
          end)
          |> Enum.into(%{})
        x -> x
      end
    }
  end

  def valid?(input, %Spec{}=spec) do
    spec.validate.(input)
  end

  def coerce!(input, %Spec{}=spec) do
    spec.coerce.(input)
  end

  def add_coersion(%Spec{}=spec, coerce) do
    %{spec | coerce: fn x -> coerce.(spec.coerce.(x)) end}
  end

  def with_coersion(%Spec{}=spec, coerce) do
    %{spec | coerce: coerce}
  end

  def all(tag \\ nil, specs) when is_list(specs) do
    # Convert any bare functions into specs. This will pass through
    # any specs that already exist
    specs = for spec <- specs, do: spec(spec)

    %Spec{
      tag: tag,
      validate: fn x -> Enum.all?(specs, & valid?(x, &1)) end,
      coerce: fn x -> Enum.reduce(specs, x, fn spec, coerced ->
          spec.coerce.(coerced)
        end)
      end
    }
  end

  def dispatch(tag \\ nil, select, map) when is_map(map) do
    %Spec{
      tag: tag,
      validate: fn x ->
        key = select.(x)
        spec = Map.get(map, key)
        spec.validate.(x)
      end,
      coerce: fn x ->
        key = select.(x)
        spec = Map.get(map, key)
        spec.coerce.(x)
      end
    }
  end

  def oneof(tag \\ nil, specs) when is_list(specs) do
    %Spec{
      tag: tag,
      validate: fn x -> Enum.any?(specs, & valid?(x, &1)) end,
      coerce: fn x -> x end,
    }
  end

  def list(tag \\ nil, spec, _opts \\ []) do
    %Spec{
      tag: tag,
      validate: fn list ->
        is_list(list) && Enum.all?(list, fn i -> valid?(i, spec) end)
      end,
      coerce: fn input -> Enum.map(input, & spec.coerce.(&1)) end
    }
  end

  def atom(tag \\ nil) do
    %Spec{
      tag: tag,
      validate: &is_atom/1,
      coerce: fn
        x when is_atom(x) -> x
        x when is_binary(x) -> String.to_atom(x)
      end
    }
  end

  def string(tag \\ nil) do
    %Spec{
      tag: tag,
      validate: &String.valid?/1,
      coerce: fn x -> to_string(x) end
    }
  end

  def binary(tag \\ nil) do
    %Spec{
      tag: tag,
      validate: &is_binary/1,
      coerce: fn x -> to_string(x) end
    }
  end

  def int(tag \\ nil) do
    %Spec{
      tag: tag,
      validate: &is_integer/1,
      coerce: fn
        x when is_binary(x) -> String.to_integer(x)
        x when is_integer(x) -> x
      end
    }
  end
end
