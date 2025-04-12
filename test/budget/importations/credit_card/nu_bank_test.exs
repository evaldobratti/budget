defmodule Budget.Importations.CreditCard.NuBankTest do
  use Budget.DataCase, async: true

  alias Budget.Importations.CreditCard.NuBank

  test "input with dollars bill" do
    {:ok, text} = File.read("test/budget/importations/files/credit_card/nu_bank/input2.txt")
    result = NuBank.process_text(text)

    assert %{
              conversion: true,
              transactions: [
                %{date: ~D[2022-09-06], description: "Humblebundle.Com", ix: 0, type: :transaction, value: -9.76},
                %{date: ~D[2022-09-09], description: "Pag*Henriqueeduardofa", ix: 1, type: :transaction, value: -4.0},
                %{date: ~D[2022-09-09], description: "Mp *Freitas", ix: 2, type: :transaction, value: -7.0, warning: "Confirm the value of this transaction!"},
                %{date: ~D[2022-09-10], description: "Posto Barcelona", ix: 3, type: :transaction, value: -13.46},
                %{date: ~D[2022-09-10], description: "Argentino", ix: 4, type: :transaction, value: -3.2},
                %{date: ~D[2022-09-10], description: "Tangerina", ix: 5, type: :transaction, value: -3.5},
                %{date: ~D[2022-09-11], description: "Grupo Ribeiro", ix: 6, type: :transaction, value: -1.55},
                %{date: ~D[2022-09-11], description: "Cafe da Vovo", ix: 7, type: :transaction, value: -18.7},
                %{date: ~D[2022-09-11], description: "Malte Produtos Aliment", ix: 8, type: :transaction, value: -24.0},
                %{date: ~D[2022-09-11], description: "Mcdonalds", ix: 9, type: :transaction, value: -1.0},
                %{date: ~D[2022-09-12], description: "Lacafeteria", ix: 10, type: :transaction, value: -1.5},
                %{date: ~D[2022-09-12], description: "Pg *Pizzaria Marcelus", ix: 11, type: :transaction, value: -8.0},
                %{date: ~D[2022-09-12], description: "Supermercado Fasan Exp", ix: 12, type: :transaction, value: -8.48},
                %{date: ~D[2022-09-14], description: "Airbnb Pagam*Airbnb *", ix: 13, type: :transaction, value: -233513.8},
                %{date: ~D[2022-09-16], description: "Mercadolivre*Brewland", ix: 14, type: :transaction, value: -8.11},
                %{date: ~D[2022-09-17], description: "Mercadochef", ix: 15, type: :transaction, value: -1.98},
                %{date: ~D[2022-09-17], description: "Ifood *Ifood", ix: 16, type: :transaction, value: -3.5},
                %{date: ~D[2022-09-18], description: "Apple.Com/Bill", ix: 17, type: :transaction, value: -9.9},
                %{date: ~D[2022-09-18], description: "Malte Produtos Aliment", ix: 18, type: :transaction, value: -210.0, warning: "Confirm the value of this transaction!"},
                %{date: ~D[2022-09-18], description: "Itiban Lavanderias", ix: 19, type: :transaction, value: -7.96},
                %{date: ~D[2022-09-19], description: "Bf Padaria", ix: 20, type: :transaction, value: -4.5},
                %{date: ~D[2022-09-20], description: "Tim*Tim", ix: 21, type: :transaction, value: -3.0},
                %{date: ~D[2022-09-20], description: "Saint Patricks Barber", ix: 22, type: :transaction, value: -4.0},
                %{date: ~D[2022-09-20], description: "Trago Comercio", ix: 23, type: :transaction, value: -2.9},
                %{date: ~D[2022-09-20], description: "Thecoffee.Jp", ix: 24, type: :transaction, value: -3.9},
                %{date: ~D[2022-09-21], description: "Mp *Freitas", ix: 25, type: :transaction, value: -7.0},
                %{date: ~D[2022-09-21], description: "Tim*44999018790", ix: 26, type: :transaction, value: -3.0},
                %{date: ~D[2022-09-21], description: "Supermercados Cidade C", ix: 27, type: :transaction, value: -62.35},
                %{date: ~D[2022-09-21], description: "Pier Coffe", ix: 28, type: :transaction, value: -8.0},
                %{date: ~D[2022-09-21], description: "Pag*Farmaciassaopaulo", ix: 29, type: :transaction, value: -9.32},
                %{ix: 30, type: :page_break},
                %{date: ~D[2022-09-22], description: "Farmacias Angeloni", ix: 31, type: :transaction, value: -1.8},
                %{date: ~D[2022-09-22], description: "Embalagens Arco Iris", ix: 32, type: :transaction, value: -2.65},
                %{date: ~D[2022-09-24], description: "Mp*Shellbox", ix: 33, type: :transaction, value: -81.34},
                %{date: ~D[2022-09-26], description: "Grupo Ribeiro", ix: 34, type: :transaction, value: -3.23},
                %{date: ~D[2022-09-27], description: "Pag*Multiutilidades", ix: 35, type: :transaction, value: -2.4},
                %{date: ~D[2022-09-28], description: "Marco'S Padaria Gourme", ix: 36, type: :transaction, value: -3.38},
                %{date: ~D[2022-09-28], description: "Pag*Pratodanutri", ix: 37, type: :transaction, value: -63.0},
                %{ix: 38, type: :page_break}
              ]
            } == result
  end

  test "basic input" do
    {:ok, text} = File.read("test/budget/importations/files/credit_card/nu_bank/input.txt")

    result = NuBank.process_text(text)

    assert %{
             conversion: false,
             transactions: [
               %{
                 date: ~D[2022-12-30],
                 description: "Restaure - Dr.Somthing. - 3/3",
                 ix: 0,
                 type: :transaction,
                 value: -100.00
               },
               %{
                 date: ~D[2022-12-30],
                 description: "Auto Mecanica Bachega - 2/2",
                 ix: 1,
                 type: :transaction,
                 value: -99.00
               },
               %{
                 date: ~D[2022-12-30],
                 description: "Pag*Kubaaudio - 2/2",
                 ix: 2,
                 type: :transaction,
                 value: -11.50
               },
               %{
                 date: ~D[2022-12-31],
                 description: "Mp*Shellbox",
                 ix: 3,
                 type: :transaction,
                 value: -17.03
               },
               %{
                 date: ~D[2022-12-31],
                 description: "Restaurante e Lanchon",
                 ix: 4,
                 type: :transaction,
                 value: -27.00
               },
               %{
                 date: ~D[2022-12-31],
                 description: "Pamonha do Cezar",
                 ix: 5,
                 type: :transaction,
                 value: -29.00
               },
               %{
                 date: ~D[2022-12-31],
                 description: "Restaurante Kioto",
                 ix: 6,
                 type: :transaction,
                 value: -11.78
               },
               %{
                 date: ~D[2022-12-31],
                 description: "Posto Portelo",
                 ix: 7,
                 type: :transaction,
                 value: -40.07
               },
               %{
                 date: ~D[2022-12-31],
                 description: "Posto Sameiro",
                 ix: 8,
                 type: :transaction,
                 value: -16.00
               },
               %{
                 date: ~D[2023-01-01],
                 description: "Restaurante Vila Nova",
                 ix: 9,
                 type: :transaction,
                 value: -40.00
               },
               %{
                 date: ~D[2023-01-01],
                 description: "Posto Vila Nova",
                 ix: 10,
                 type: :transaction,
                 value: -6.50
               },
               %{
                 date: ~D[2023-01-01],
                 description: "Posto Vila Nova",
                 ix: 11,
                 type: :transaction,
                 value: -2.00
               },
               %{
                 date: ~D[2023-01-01],
                 description: "Vilma Olenka Flocos",
                 ix: 12,
                 type: :transaction,
                 value: -9.00
               },
               %{
                 date: ~D[2023-01-02],
                 description: "Pizzas Vitoria",
                 ix: 13,
                 type: :transaction,
                 value: -2.00
               },
               %{
                 date: ~D[2023-01-03],
                 description: "Pagamento em 03 JAN",
                 ix: 14,
                 type: :transaction,
                 uncomplete: true,
                 value: 1000.00
               },
               %{
                 date: ~D[2023-01-03],
                 description: "Amauri Center",
                 ix: 15,
                 type: :transaction,
                 value: -7.71
               },
               %{
                 date: ~D[2023-01-03],
                 description: "Posto Delta",
                 ix: 16,
                 type: :transaction,
                 value: -5.45
               },
               %{
                 date: ~D[2023-01-03],
                 description: "Mp*Shellbox",
                 ix: 17,
                 type: :transaction,
                 value: -24.27
               },
               %{
                 date: ~D[2023-01-03],
                 description: "Posto Brasilia",
                 ix: 18,
                 type: :transaction,
                 value: -15.48
               },
               %{
                 date: ~D[2023-01-05],
                 description: "Saint Patricks Barber",
                 ix: 19,
                 type: :transaction,
                 value: -4.00
               },
               %{
                 date: ~D[2023-01-05],
                 description: "Pag*Andreborges",
                 ix: 20,
                 type: :transaction,
                 value: -3.00
               },
               %{
                 date: ~D[2023-01-06],
                 description: "Amazon.Com.Br",
                 ix: 21,
                 type: :transaction,
                 value: -7.08
               },
               %{
                 date: ~D[2023-01-07],
                 description: "Amazon.Com.Br",
                 ix: 22,
                 type: :transaction,
                 value: -7.08
               },
               %{
                 date: ~D[2023-01-07],
                 description: "Mercadochef",
                 ix: 23,
                 type: :transaction,
                 uncomplete: true,
                 value: -6.99
               },
               %{
                 date: ~D[2023-01-07],
                 description: "Pag*Varejaoshinnai",
                 ix: 24,
                 type: :transaction,
                 value: -16.90
               },
               %{
                 date: ~D[2023-01-07],
                 description: "Roberto'S Pastel",
                 ix: 25,
                 type: :transaction,
                 value: -4.00
               },
               %{
                 date: ~D[2023-01-08],
                 description: "Mercadochef",
                 ix: 26,
                 type: :transaction,
                 value: -3.95
               },
               %{
                 date: ~D[2023-01-08],
                 description: "Mestre Cervejeiro",
                 ix: 27,
                 type: :transaction,
                 value: -7999.00
               },
               %{
                 date: ~D[2023-01-10],
                 description: "99*Fernando Aurelio Pa",
                 ix: 28,
                 type: :transaction,
                 value: -7.83
               },
               %{
                 date: ~D[2023-01-10],
                 description: "Apoiase Atabaqueprodu",
                 ix: 29,
                 type: :transaction,
                 value: -5.00
               },
               %{
                 date: ~D[2023-01-10],
                 description: "Apoiase Varios Apoios",
                 ix: 30,
                 type: :transaction,
                 value: -3.00
               },
               %{ix: 31, type: :page_break},
               %{
                 date: ~D[2023-01-10],
                 description: "Amazon-Marketplace",
                 ix: 32,
                 type: :transaction,
                 value: -2.00
               },
               %{
                 date: ~D[2023-01-10],
                 description: "Posto Sameiro",
                 ix: 33,
                 type: :transaction,
                 value: -1.14
               },
               %{
                 date: ~D[2023-01-11],
                 description: "Supermercados Cidade C",
                 ix: 34,
                 type: :transaction,
                 value: -9.27
               },
               %{
                 date: ~D[2023-01-15],
                 description: "Mercadochef",
                 ix: 35,
                 type: :transaction,
                 value: -4.93
               },
               %{
                 date: ~D[2023-01-15],
                 description: "Grupo Ribeiro",
                 ix: 36,
                 type: :transaction,
                 value: -1.80
               },
               %{
                 date: ~D[2023-01-15],
                 description: "Companhia do Pastel",
                 ix: 37,
                 type: :transaction,
                 value: -40.00
               },
               %{
                 date: ~D[2023-01-15],
                 description: "Pag*Fcvbanhoetosaltda",
                 ix: 38,
                 type: :transaction,
                 value: -50999.08
               },
               %{
                 date: ~D[2023-01-15],
                 description: "Pag*Vanda",
                 ix: 39,
                 type: :transaction,
                 value: -1.00
               },
               %{
                 date: ~D[2023-01-15],
                 description: "Grupo Ribeiro",
                 ix: 40,
                 type: :transaction,
                 value: -1.06
               },
               %{
                 date: ~D[2023-01-16],
                 description: "Mercadochef",
                 ix: 41,
                 type: :transaction,
                 value: -3.78
               },
               %{
                 date: ~D[2023-01-17],
                 description: "Mercadochef",
                 ix: 42,
                 type: :transaction,
                 value: -2.95
               },
               %{
                 date: ~D[2023-01-18],
                 description: "Pag*Centrodeformacao",
                 ix: 43,
                 type: :transaction,
                 value: -1.00
               },
               %{
                 date: ~D[2023-01-18],
                 description: "99*Caio da Silva Santa",
                 ix: 44,
                 type: :transaction,
                 value: -9.90
               },
               %{
                 date: ~D[2023-01-19],
                 description: "Mp*Shellbox",
                 ix: 45,
                 type: :transaction,
                 value: -1.21
               },
               %{
                 date: ~D[2023-01-19],
                 description: "Uber *Trip Help.Uber.C",
                 ix: 46,
                 type: :transaction,
                 value: -1.95
               },
               %{
                 date: ~D[2023-01-19],
                 description: "Uber *Trip Help.Uber.C",
                 ix: 47,
                 type: :transaction,
                 value: -1.97
               },
               %{
                 date: ~D[2023-01-21],
                 description: "Pamonha do Cezar",
                 ix: 48,
                 type: :transaction,
                 value: -299.99
               },
               %{
                 date: ~D[2023-01-21],
                 description: "Farmacia Sao Joao",
                 ix: 49,
                 type: :transaction,
                 value: -1.90
               },
               %{
                 date: ~D[2023-01-22],
                 description: "Mercadochef",
                 ix: 50,
                 type: :transaction,
                 value: -2.95
               },
               %{
                 date: ~D[2023-01-22],
                 description: "Raia",
                 ix: 51,
                 type: :transaction,
                 value: -2.34
               },
               %{
                 date: ~D[2023-01-23],
                 description: "Ifood *Ifd",
                 ix: 52,
                 type: :transaction,
                 value: -2.50
               },
               %{
                 date: ~D[2023-01-23],
                 description: "Pag*Esquinadopao",
                 ix: 53,
                 type: :transaction,
                 value: -3.00
               },
               %{
                 date: ~D[2023-01-24],
                 description: "Mercadochef",
                 ix: 54,
                 type: :transaction,
                 value: -15.08
               },
               %{
                 date: ~D[2023-01-24],
                 description: "Uber *Uber *Trip",
                 ix: 55,
                 type: :transaction,
                 value: -1.95
               },
               %{
                 date: ~D[2023-01-24],
                 description: "Uber *Trip Help.Uber.C",
                 ix: 56,
                 type: :transaction,
                 value: -1.92
               },
               %{
                 date: ~D[2023-01-24],
                 description: "Automecanica Lider",
                 ix: 57,
                 type: :transaction,
                 uncomplete: true,
                 value: -10397.00
               },
               %{
                 date: ~D[2023-01-25],
                 description: "Restaurante Kioto",
                 ix: 58,
                 type: :transaction,
                 value: -9.08
               },
               %{
                 date: ~D[2023-01-26],
                 description: "Iugu*Myprofit",
                 ix: 59,
                 type: :transaction,
                 value: -1.00
               },
               %{
                 date: ~D[2023-01-27],
                 description: "Mp*Shellbox",
                 ix: 60,
                 type: :transaction,
                 value: -1.27
               },
               %{
                 date: ~D[2023-01-28],
                 description: "Mercado Itamaraty Cer",
                 ix: 61,
                 type: :transaction,
                 value: -6.98
               },
               %{
                 date: ~D[2023-01-29],
                 description: "Marina S Chipas",
                 ix: 62,
                 type: :transaction,
                 value: -2.00
               },
               %{ix: 63, type: :page_break},
               %{
                 date: ~D[2023-01-29],
                 description: "Supermercados Cidade C",
                 ix: 64,
                 type: :transaction,
                 value: -1.43
               },
               %{ix: 65, type: :page_break}
             ]
           } == result
  end
end
