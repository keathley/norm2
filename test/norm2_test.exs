defmodule Norm2Test do
  use ExUnit.Case
  doctest Norm2, import: true

  import Norm2

  defmodule MyList do
    defstruct list: []

    import Norm2

    def s do
      spec(%__MODULE__{
        list: list(all([int(), fn x -> x > 0 end]))
      })
    end
  end

  defmodule FooEvent do
    defstruct value: nil

    import Norm2

    def s do
      spec(%__MODULE__{
        value: string(),
      })
    end
  end

  defmodule UserEvent do
    import Norm2

    defstruct user_id: nil

    def s do
      spec(%__MODULE__{
        user_id: int()
      })
    end
  end

  test "valid?/2" do
    refute valid?(1, spec(fn x -> false end))
    assert valid?("test", spec(&is_binary/1))

    user =
      spec(%{
        name: string(),
        age: all([int(), fn x -> x > 0 end])
      })

    assert valid?(%{name: "chris", age: 35}, user)
    refute valid?(%{name: "chris", age: -35}, user)
    refute valid?(%{name: :chris, age: 35}, user)
    refute valid?(%{age: 35}, user)
    refute valid?(%{other: 123}, user)
    refute valid?(%{}, user)

    my_list = MyList.s()
    assert valid?(%MyList{list: [1, 2, 3, 4, 5]}, my_list)
    refute valid?(%MyList{list: ["1", 2.0, 3]}, my_list)
  end

  test "coerce!/2" do
    assert "1" == coerce!(1, string())
    assert "1" == coerce!("1", string())
    assert 1 == coerce!(1, int())
    assert 1 == coerce!("1", int())

    assert :hello == coerce!("hello", atom())

    user =
      spec(%{
        name: string(),
        age: all([int(), fn x -> x > 0 end])
      })
    assert %{name: "chris", age: 35} == coerce!(%{
      "name" => "chris",
      "age" => "35"
    }, user)

    assert %MyList{list: [1,2,3,4,5]} == coerce!(%{"list" => ["1", 2, 3, 4, 5]}, MyList.s())

    s =
      MyList.s()
      |> with_coersion(fn list -> coerce!(%MyList{list: list}, MyList.s()) end)
    assert %MyList{list: [2,3,4]} == coerce!(["2", "3", "4"], s)

    events = dispatch(fn x -> x["type"] end, %{
      "user_event" => UserEvent.s(),
      "foo" => FooEvent.s()
    })
    assert %UserEvent{user_id: 1234} == coerce!(%{"type" => "user_event", "user_id" => 1234}, events)
    assert %FooEvent{value: "test"} == coerce!(%{"type" => "foo", "value" => "test"}, events)
  end
end
