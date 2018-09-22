defmodule AdminAppWeb.OrderView do
  use AdminAppWeb, :view
  alias Phoenix.HTML.FormData
  alias Snitch.Data.Model.Order, as: OrderModel
  alias Snitch.Data.Model.{LineItem, Country, State}
  alias Snitch.Repo
  alias Snitch.Domain.Order, as: OrderDomain
  alias Snitch.Data.Model.LineItem

  @bootstrap_contextual_class %{
    "slug" => "light",
    "cart" => "light",
    "address" => "light",
    "payment" => "light",
    "processing" => "warning",
    "shipping" => "warning",
    "shipped" => "info",
    "cancelled" => "secondary",
    "completed" => "success"
  }

  @summary_fields ~w(item_total tax_total adjustment_total promo_total total)a
  @summary_fields_capitalized Enum.map(@summary_fields, fn field ->
                                field
                                |> Atom.to_string()
                                |> String.replace("_", " ")
                                |> String.capitalize()
                              end)
  @summary_field_classes %{
    total: "table-secondary"
  }

  def colorize(%{state: state}) do
    "table-" <> Map.fetch!(@bootstrap_contextual_class, state)
  end

  def state_badge(state) do
    color_class = @bootstrap_contextual_class[state]
    content_tag(:span, state, class: "badge badge-pill badge-#{color_class}")
  end

  defp render_line_item(line_item, order) do
    content = [
      render_variant(line_item.product),
      content_tag(:td, line_item.unit_price),
      render_quantity_with_stock(line_item),
      render_update_buttons(line_item.id, order),
      render_buttons(line_item.id, order)
    ]

    content_tag(:tr, List.flatten(content))
  end

  def render_variant(product) do
    content_tag(:td, product.sku)
  end

  defp render_update_buttons(item, order) do
    if is_editable?(order.state) do
      content_tag(
        :td,
        form_tag "/orders/#{order.number}/cart/edit?update=#{item}", method: "post" do
          content_tag(:button, ["update"], class: "btn btn-primary", type: "submit")
        end
      )
    end
  end

  defp render_buttons(item, order) do
    if is_editable?(order.state) do
      content_tag(
        :td,
        form_tag "/orders/#{order.number}/cart?edit=#{item}", method: "post" do
          content_tag(:button, ["remove"], class: "btn btn-primary", type: "submit")
        end
      )
    end
  end

  def render_quantity_with_stock(line_item) do
    content_tag(:td, "#{line_item.quantity} x on hand")
  end

  def render_address(address) do
    content_tag(
      :div,
      [
        content_tag(:div, ["#{address.first_name} #{address.last_name}"], class: "name"),
        content_tag(
          :div,
          [
            address.address_line_1,
            address.address_line_2,
            address.city,
            address.phone,
            address.zip_code
          ]
          |> Enum.reject(&(&1 == nil))
          |> Enum.intersperse([",", tag(:br)])
          |> List.flatten(),
          class: "addres-detail"
        )
      ]
    )
  end

  defp summary(order) do
    content_tag(
      :tbody,
      @summary_fields
      |> Stream.zip(@summary_fields_capitalized)
      |> Enum.map(&make_summary_row(&1, order))
    )
  end

  defp make_summary_row({field, field_capitalized}, order) when field in ~w(item_total total)a do
    content_tag(
      :tr,
      [
        content_tag(:th, field_capitalized, scope: "row"),
        content_tag(:td, LineItem.compute_total(order.line_items))
      ],
      class: Map.get(@summary_field_classes, field)
    )
  end

  defp make_summary_row({field, field_capitalized}, order) do
    content_tag(
      :tr,
      [
        content_tag(:th, field_capitalized, scope: "row"),
        content_tag(:td, Snitch.Tools.Money.zero!())
      ],
      class: Map.get(@summary_field_classes, field)
    )
  end

  defp is_editable?(_), do: true

  defp render_search_item(item, order) do
    content = [
      content_tag(:td, item.sku),
      content_tag(:td, item.selling_price),
      content_tag(:td, tag(:input, name: "quantity", id: "quantity")),
      content_tag(:td, content_tag(:button, ["Add"], type: "submit"))
    ]

    list =
      form_tag "/orders/#{order.number}/cart?add=#{item.id}", method: "put" do
        List.flatten(content)
      end

    content_tag(:tr, list)
  end

  def render_update_item(item, order) do
    content = [
      content_tag(:td, item.product.sku),
      content_tag(:td, item.product.selling_price),
      content_tag(:td, tag(:input, name: "quantity", value: item.quantity)),
      content_tag(:td, tag(:hidden, name: "product_id", value: item.product_id)),
      content_tag(:td, content_tag(:button, ["Add"], type: "submit"))
    ]

    list =
      form_tag "/orders/#{order.number}/cart/update?update=#{item.id}", method: "put" do
        List.flatten(content)
      end

    content_tag(:tr, list)
  end

  def build_address(address, order) do
    content = [
      content_tag(:td, address.first_name),
      content_tag(:td, address.last_name),
      content_tag(:td, address.address_line_1),
      content_tag(:td, address.phone),
      content_tag(:td, address.city),
      content_tag(
        :td,
        content_tag(:button, ["Attach"], type: "submit", class: "btn btn-sm btn-primary")
      )
    ]

    list =
      form_tag "/orders/#{order.number}/address/search?address_id=#{address.id}", method: "put" do
        List.flatten(content)
      end

    content_tag(:tr, list)
  end

  def display_email(order) do
    if order.user do
      order.user.email
    else
      "Guest Order"
    end
  end

  def render_invoice_links(order) do
    order_new =
      order
      |> Repo.preload(:line_items)
      |> Repo.preload(:user)

    html = Phoenix.View.render_to_string(AdminAppWeb.OrderView, "invoice.html", order: order_new)

    payslip_html =
      Phoenix.View.render_to_string(AdminAppWeb.OrderView, "packing_slip.html", order: order_new)

    {:ok, file} = PdfGenerator.generate_binary(html, page_size: "A4", delete_temporary: false)

    {:ok, packing_slip_file} =
      PdfGenerator.generate_binary(payslip_html, page_size: "A4", delete_temporary: false)

    path = "invoices/#{order.number}.pdf"
    packing_slip_path = "invoices/packing_slip_#{order.number}.pdf"
    File.write(path, file)
    File.write(packing_slip_path, packing_slip_file)

    content = [
      content_tag(
        :a,
        "Download Invoice",
        href: "#{order.number}/download-invoice",
        class: "btn btn-primary",
        style: "margin-right: 3px;"
      ),
      content_tag(
        :a,
        "Show Packing Slip",
        href: "#{order.number}/show-packing-slip",
        class: "btn btn-primary",
        style: "margin-right: 3px;"
      ),
      content_tag(
        :a,
        "Download Packing Slip",
        href: "#{order.number}/download-packing-slip",
        class: "btn btn-primary",
        style: "margin-right: 3px;"
      )
    ]

    content_tag(:div, content)
  end

  defp render_invoice_line_item(line_item, order) do
    content = [
      render_variant(line_item.product),
      render_quantity(line_item),
      content_tag(:td, " #{line_item.unit_price} ")
    ]

    content_tag(:tr, List.flatten(content))
  end

  defp render_quantity(line_item) do
    content_tag(:td, " x #{line_item.quantity}")
  end

  defp get_country(country_id) do
    Country.get(country_id)
  end

  defp get_state(state_id) do
    State.get(state_id)
  end

  defp get_state_name(state_id) do
    state_id |> get_state() |> Map.get(:name)
  end

  defp get_iso(country_id) do
    country_id |> get_country() |> Map.get(:iso)
  end

  def order_total(order) do
    {:ok, total} = Money.to_string(OrderDomain.total_amount(order))
    total
  end
end
