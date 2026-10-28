import React, { useState, useEffect } from "react";
import { fetchCart, applyDiscount, fetchGet, fetchRequest } from "../../lib/api";

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

  if (loading) return <p style={{ padding: "20px" }}>Loading your cart...</p>;

  return (
    <div style={{ padding: "20px", maxWidth: "800px", margin: "0 auto" }}>
      <h2>Your Shopping Cart</h2>
      
      {cartError ? (
        <p role="alert" style={{ padding: "20px 0", color: "#b00020" }}>{cartError}</p>
      ) : !cart || !cart.items || cart.items.length === 0 ? (
        <p style={{ padding: "20px 0", fontStyle: "italic", color: "#666" }}>Your cart is empty.</p>
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

            <div style={{ marginTop: "20px", display: "flex", gap: "10px" }}>
              <input
                type="text"
                value={discountCode}
                onChange={(e) => setDiscountCode(e.target.value)}
                placeholder="Enter promo code"
                style={{ padding: "8px", flex: 1, border: "1px solid #ccc", borderRadius: "4px" }}
              />
              <button 
                onClick={handleApplyDiscount} 
                style={{ padding: "8px 16px", cursor: "pointer", background: "#eee", border: "1px solid #ccc", borderRadius: "4px" }}>
                Apply
              </button>
            </div>
            
            {discountMessage && (
              <p style={{ color: discountMessage.includes("Invalid") ? "red" : "green", marginTop: "10px", fontSize: "0.9em" }}>
                {discountMessage}
              </p>
            )}

            <button 
              onClick={handleCheckout}
              style={{ marginTop: "20px", padding: "12px", width: "100%", background: "#000", color: "#fff", cursor: "pointer", border: "none", borderRadius: "4px" }}>
              Proceed to Checkout
            </button>
          </div>
        </>
      )}

      {/* --- Past Orders Section --- */}
      {orders.length > 0 && (
        <div style={{ marginTop: "60px", paddingTop: "20px", borderTop: "2px solid #eee" }}>
          <h2>Your Past Orders</h2>
          {orders.map((order) => (
            <div key={order.id} style={{ marginBottom: "20px", padding: "20px", border: "1px solid #e0e0e0", borderRadius: "8px", backgroundColor: "#fafafa" }}>
              <h3 style={{ marginTop: 0 }}>
                Order #{order.id} <span style={{ fontSize: "0.8em", color: "#666", fontWeight: "normal", marginLeft: "10px" }}>({order.status})</span>
              </h3>
              
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
            </div>
          ))}
        </div>
      )}
    </div>
  );
}