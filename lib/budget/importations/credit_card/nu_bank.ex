defmodule Budget.Importations.CreditCard.NuBank do

  @months_pt %{
    "JAN" => 1,
    "FEV" => 2,
    "MAR" => 3,
    "ABR" => 4,
    "MAI" => 5,
    "JUN" => 6,
    "JUL" => 7,
    "AGO" => 8,
    "SET" => 9,
    "OUT" => 10,
    "NOV" => 11,
    "DEZ" => 12
    }

  def import(file) do
    text = 
      if String.ends_with?(file, "txt") do
        {:ok, text} = File.read(file)
        text
      else
        {text, 0} = System.cmd("pdftotext", [file, "-"])
        text
      end

    process_text(text)
  end

  def process_text(text) do
    [_page1, _page2, _page3 | transactions] =
      text
      |> String.split("\f")

    result =
      transactions
      |> List.flatten()
      |> Enum.map(&String.split(&1, "\n"))
      |> List.flatten()
      |> Enum.filter(&(&1 != ""))
      |> Enum.map(fn string ->
        cond do
          string == "TRANSAÇÕES" ->
            {:transactions, string}

          string == "VALORES EM R$" ->
            :ignore

          String.starts_with?(string, "USD") ->
            :ignore

          String.starts_with?(string, "Conversão") ->
            {:conversion, string}

          Regex.match?(~r/\d+ de \d+/, string) ->
            {:page_break, string}

          Regex.match?(~r/DE \d{2} \w{3} A \d{2} \w{3}/, string) ->
            {:period, string}

          Regex.match?(~r/^\d{2} \w{3}$/, string) ->
            {:date, string}

          Regex.match?(~r/(\d*\.)?\d+,\d{2}/, string) ->
            value =
              string
              |> String.replace(".", "")
              |> String.replace(",", ".")

            {:value, value}

          true ->
            {:description, string}
        end
      end)
      |> Enum.filter(& &1 != :ignore)
      |> Enum.reduce(
        %{
          building: %{},
          transactions: [],
          uncomplete_descriptions: [],
          uncomplete_values: [],
          ix: 0,
          state: :initial,
          conversion: false,
          base_date: nil,
          base_month: nil,
          base_year: nil
        },
        fn
          {:description, _name}, %{state: :initial} = acc ->
            %{acc | state: :period_description}

          {:description, period}, %{state: :period_description} = acc ->
            splitted = String.split(period, " ")
            year = Enum.at(splitted, -1)
            month = Enum.at(splitted, -2)
            day = Enum.at(splitted, -3)

            {:ok, base_date} = Date.new(String.to_integer(year), @months_pt[month], String.to_integer(day))

            %{acc | state: :transactions, base_date: base_date, base_year: year, base_month: month}

          {:transactions, _transactions}, %{state: :transactions} = acc ->
            %{acc | state: :period}

          {:period, _period}, %{state: :period} = acc ->
            %{acc | state: :values_description}

          {:description, _}, %{state: :values_description} = acc ->
            %{acc | state: :date, }

          {:date, date}, %{state: state} = acc when state in [:date, :values_description] ->
            acc
            |> Map.put(:building, %{ix: acc.ix, date: date, type: :transaction})
            |> Map.put(:ix, acc.ix + 1)
            |> Map.put(:state, :description)

          {:value, value}, %{state: :date} = acc ->
            acc
            |> Map.put(:uncomplete_values, [value | acc.uncomplete_values])
            |> Map.put(:state, :date)

          {:description, description}, %{state: :description} = acc ->
            acc
            |> Map.put(:building, Map.put(acc.building, :description, description))
            |> Map.put(:state, :value)

          {:value, value}, %{state: :value} = acc ->
            adjusted = 
              if String.contains?(acc.building.description, "Pagamento em") do
                String.to_float(value)
              else
                -String.to_float(value)
              end

            acc
            |> Map.put(:building, %{})
            |> Map.put(:transactions, [Map.put(acc.building, :value, adjusted) | acc.transactions])
            |> Map.put(:state, :date)

          {:date, date}, %{state: :value} = acc ->
            acc
            |> Map.put(:building, %{ix: acc.ix, date: date, type: :transaction})
            |> Map.put(:uncomplete_descriptions, [acc.building | acc.uncomplete_descriptions])
            |> Map.put(:ix, acc.ix + 1)
            |> Map.put(:state, :description)

          {:page_break, _}, acc ->
            acc
            |> Map.put(:transactions, [%{type: :page_break, ix: acc.ix} | acc.transactions])
            |> Map.put(:ix, acc.ix + 1)
            |> Map.put(:state, :initial)

          {:conversion, _}, acc ->
            acc
            |> Map.put(:conversion, true)
        end
      )

    uncomplete = 
      result.uncomplete_descriptions
      |> Enum.zip(result.uncomplete_values)
      |> Enum.map(fn {descriptions, value} -> 
        adjusted = 
          if String.contains?(descriptions.description, "Pagamento em") do
            String.to_float(value)
          else
            -String.to_float(value)
          end
        
        Map.put(descriptions, :value, adjusted) 
      end)
      |> Enum.map(& Map.put(&1, :uncomplete, true))

    transactions = 
      result.transactions
      |> Enum.concat(uncomplete)
      |> Enum.sort_by(& &1.ix)
      |> Enum.map(fn 
        %{date: date} = transaction ->
          [day, month] = String.split(date, " ")

          year =
            if month == result.base_month do
              String.to_integer(result.base_year)
            else
              previous_month = result.base_date |> Timex.shift(months: -1)
              previous_month.year
            end

          {:ok, date} = Date.new(year, @months_pt[month], String.to_integer(day))

          %{transaction | date: date}

        other -> 
          other
      end)

    %{
      transactions: transactions,
      conversion: result.conversion,
    }
  end
end
