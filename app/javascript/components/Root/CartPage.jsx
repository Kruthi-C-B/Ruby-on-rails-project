import React, { useState, useEffect } from "react";
import { fetchCart, applyDiscount, fetchGet, fetchRequest } from "../../lib/api";
import { Alert, Badge, Button, Card, EmptyState, Input, PageContainer, PageHeader, Section, Spinner } from "../ui";

export default function CartPage() {
  const [cart, setCart] = useState(null);
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [cartError, setCartError] = useState("");
  const [discountCode, setDiscountCode] = useState("");
  const [discountMessage, setDiscountMessage] = useState("");
  const [availableDiscounts, setAvailableDiscounts] = useState([]);

  useEffect(() => {
    loadCart();
    loadDiscounts();
    loadOrders();

  }, []);

  const loadCart = async () => {
    setLoading(true);
    try {
      const data = await fetchCart();
      console.log("Cart items:", data.items);
      console.log("Cart item IDs:", data.items?.map((item) => item.id));

      setCart(data);
      setCartError("");
    } catch (error) {
      console.error("Failed to load cart", error);
      setCartError(error.message || "Unable to load your cart. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const loadOrders = async () => {
    try {
      const data = await fetchGet("/api/v1/users/cart/orders");

      console.log("Orders:", data);

    console.log(
      "Past order item IDs:",
      data.flatMap((order) =>
        (order.cart_items || []).map((item) => ({
          orderId: order.id,
          itemId: item.id,
        }))
      )
    );


      setOrders(data);
    } catch (error) {
      console.error("Failed to load orders", error);
    }
  };

  const loadDiscounts = async () => {
    try {
      const data = await fetchGet("/api/v1/discounts");
      setAvailableDiscounts(data);
    } catch (error) {
      console.error("Failed to load discounts", error);
    }
  };

  const handleApplyDiscount = async () => {
    try {
      const data = await applyDiscount(discountCode);
      setCart(data);
      setDiscountMessage("Discount applied successfully!");
    } catch (error) {
      setDiscountMessage("Invalid or expired discount code.");
    }
  };

  const handleCheckout = async () => {
    try {
      await fetchRequest("/api/v1/users/cart/checkout", "POST");
      alert("Order successful!");
      loadCart();
      loadOrders();
    } catch (error) {
      alert(error.message || "Failed to process checkout.");
    }
  };

  if (loading) return <PageContainer size="narrow"><Spinner label="Loading your cart…" /></PageContainer>;

  return (
    <PageContainer size="narrow">
      <PageHeader title="Your Shopping Cart" />
      
      {cartError ? (
        <Alert>{cartError}</Alert>
      ) : !cart || !cart.items || cart.items.length === 0 ? (
        <EmptyState title="Your cart is empty." />
      ) : (
        <>
          <table style={{ width: "100%", textAlign: "left", borderCollapse: "collapse", marginBottom: "30px" }}>
            <thead>
              <tr style={{ borderBottom: "2px solid #ccc" }}>
                <th style={{ paddingBottom: "10px" }}>Product</th>
                <th style={{ paddingBottom: "10px" }}>Quantity</th>
                <th style={{ paddingBottom: "10px" }}>Unit Price</th>
                <th style={{ paddingBottom: "10px" }}>Total</th>
              </tr>
            </thead>
            <tbody>
              {cart.items.map((item) => (
                <tr key={item.id} style={{ borderBottom: "1px solid #eee" }}>
                  <td style={{ padding: "15px 0" }}>
                    {item.product_listing?.product?.name || "Unknown Product"}
                  </td>
                  <td>{item.quantity}</td>
                  <td>${parseFloat(item.unit_price).toFixed(2)}</td>
                  <td>${(item.unit_price * item.quantity).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div style={{ borderTop: "2px solid #ccc", paddingTop: "20px", maxWidth: "350px", marginLeft: "auto" }}>
            
            {availableDiscounts.length > 0 && (
              <div style={{ padding: "15px", backgroundColor: "#e8f4f8", border: "1px solid #b6d4fe", borderRadius: "5px", marginBottom: "20px" }}>
                <strong style={{ color: "#004085" }}>🔥 Available Promo Codes:</strong>
                <ul style={{ margin: "10px 0 0 0", paddingLeft: "20px", color: "#004085", fontSize: "0.9em" }}>
                  {availableDiscounts.map(discount => (
                    <li key={discount.id} style={{ marginBottom: "5px" }}>
                      Use code <strong>{discount.code}</strong> for {parseFloat(discount.percentage)}% off!
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "10px" }}>
              <span>Subtotal:</span>
              <span>${parseFloat(cart.subtotal).toFixed(2)}</span>
            </div>
            
            {cart.discount_percentage && (
              <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "10px", color: "green" }}>
              <span>Discount Applied ({parseFloat(cart.discount_percentage)}%):</span>
              <span>-${parseFloat(cart.discount_amount).toFixed(2)}</span>
              </div>
            )}
            
            <div style={{ display: "flex", justifyContent: "space-between", fontSize: "1.2em", fontWeight: "bold", marginTop: "10px" }}>
              <span>Total:</span>
              <span>${parseFloat(cart.total_price).toFixed(2)}</span>
            </div>

            <div className="lf-inline-form" style={{ marginTop: "20px" }}>
              <Input
                type="text"
                aria-label="Promo code"
                value={discountCode}
                onChange={(e) => setDiscountCode(e.target.value)}
                placeholder="Enter promo code"
              />
              <Button variant="secondary" onClick={handleApplyDiscount}>
                Apply
              </Button>
            </div>
            
            {discountMessage && (
              <Alert variant={discountMessage.includes("Invalid") ? "error" : "success"}>
                {discountMessage}
              </Alert>
            )}

            <Button
              onClick={handleCheckout}
              className="lf-button--full"
              style={{ marginTop: "20px" }}
            >
              Proceed to Checkout
            </Button>
          </div>
        </>
      )}

      {/* --- Past Orders Section --- */}
      {orders.length > 0 && (
        <Section title="Your Past Orders">
          {orders.map((order) => (
            <Card
              key={order.id}
              variant="muted"
              className="lf-order-card"
              title={<>Order #{order.id} <Badge>{order.status}</Badge></>}
            >
              
                <table style={{ width: "100%", textAlign: "left", borderCollapse: "collapse", marginTop: "10px" }}>
                <thead>
                  <tr style={{ borderBottom: "1px solid #ccc" }}>
                    <th style={{ paddingBottom: "8px" }}>Product</th>
                    <th style={{ paddingBottom: "8px" }}>Qty</th>
                    <th style={{ paddingBottom: "8px" }}>Unit Price</th>
                    <th style={{ paddingBottom: "8px" }}>Discount</th>
                    <th style={{ paddingBottom: "8px" }}>Line Total</th>
                  </tr>
                </thead>
                <tbody>
                  {order.cart_items.map((item) => (
                    <tr key={item.id} style={{ borderBottom: "1px solid #eee" }}>
                      <td style={{ padding: "8px 0" }}>{item.product_listing?.product?.name || "Unknown Product"}</td>
                      <td>{item.quantity}</td>
                      <td>${parseFloat(item.unit_price).toFixed(2)}</td>
                      <td>-${parseFloat(item.discount_amount || 0).toFixed(2)}</td>
                      <td>${parseFloat(item.total_price || 0).toFixed(2)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <div style={{ textAlign: "right", marginTop: "15px", fontSize: "1.1em" }}>
                {Number(order.discount_amount) > 0 && (
                  <p style={{ color: "green" }}>Discount: -${parseFloat(order.discount_amount).toFixed(2)}</p>
                )}
                <strong>Total Paid: ${parseFloat(order.total_price || 0).toFixed(2)}</strong>
              </div>
          </Card>
          ))}
        </Section>
      )}
    </PageContainer>
  );
}