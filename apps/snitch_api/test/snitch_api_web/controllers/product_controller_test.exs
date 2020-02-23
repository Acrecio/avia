defmodule SnitchApiWeb.ProductControllerTest do
  use SnitchApiWeb.ConnCase, async: true

  import Snitch.Factory

  alias Snitch.Data.Schema.Product
  alias Snitch.Core.Tools.MultiTenancy.Repo

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, taxon: insert(:taxon)}
  end

  test "lists all products entries on index", %{conn: conn} do
    conn = get(conn, product_path(conn, :index))
    assert json_response(conn, 200)["data"]
  end

  test "shows chosen resource product", %{conn: conn, taxon: taxon} do
    product = insert(:product, state: "active", taxon: taxon)
    conn = get(conn, product_path(conn, :show, product.slug))

    assert json_response(conn, 200)["data"] |> Map.take(["id", "type"]) == %{
             "id" => "#{product.id}",
             "type" => "product"
           }
  end

  test "Products, search contains name and pagination", %{conn: conn, taxon: taxon} do
    product1 = insert(:product, state: "active", taxon: taxon)
    product2 = insert(:product, state: "active", taxon: taxon)
    product3 = insert(:product, state: "active", taxon: taxon)

    params = %{
      "q" => "product",
      "rows" => "50",
      "o" => "0"
    }

    conn = get(conn, product_path(conn, :index, params))

    response =
      json_response(conn, 200)["data"]
      |> Enum.count()

    assert response == 3
  end

  test "Products, sort by newly inserted", %{conn: conn, taxon: taxon} do
    product = insert(:product, state: "active", taxon: taxon)

    params = %{
      "sort" => "date"
    }

    conn = get(conn, product_path(conn, :index, params))

    response =
      json_response(conn, 200)["data"]
      |> List.first()

    assert response["attributes"]["name"] == product.name
  end
end
