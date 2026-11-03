import React from "react";
import { Alert, Badge, Card, EmptyState, Section, Spinner } from "../../ui";

export default function OrderHistory({ orders, loading, error }) {
  if (loading) return <Spinner label="Loading past orders…" />;
  if (error) return <Alert variant="error">{error}</Alert>;
  if (orders.length === 0) return <EmptyState title="You have no past orders yet." />;

  return (
    <Section title="Your Past Orders">
      {orders.map((order) => (
        <Card
          key={order.id}
          variant="muted"
          className="lf-order-card"
          title={
            <>
              Order #{order.id} <Badge>{order.status}</Badge>
            </>
          }
        >
          <div className="lf-table-scroll">
            <table className="lf-cart-table lf-cart-table--history">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Qty</th>
                  <th>Unit Price</th>
                  <th>Discount</th>
                  <th>Line Total</th>
                </tr>
              </thead>
              <tbody>
                {(order.cart_items || []).map((item) => (
                  <tr key={item.id}>
                    <td>{item.product_listing?.product?.name || "Unknown Product"}</td>
                    <td>{item.quantity}</td>
                    <td>${parseFloat(item.unit_price).toFixed(2)}</td>
                    <td>-${parseFloat(item.discount_amount || 0).toFixed(2)}</td>
                    <td>${parseFloat(item.total_price || 0).toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="lf-order-summary">
            {Number(order.discount_amount) > 0 && (
              <p className="lf-order-summary__discount">
                Discount: -${parseFloat(order.discount_amount).toFixed(2)}
              </p>
            )}
            <strong>Total Paid: ${parseFloat(order.total_price || 0).toFixed(2)}</strong>
          </div>
        </Card>
      ))}
    </Section>
  );
}
