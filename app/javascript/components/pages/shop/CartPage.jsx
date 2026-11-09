
import React, { useState, useEffect } from "react";
import {
  fetchCart,
  applyDiscount,
  fetchGet,
  fetchRequest,
} from "../../../lib/api";

import {
  Alert,
  Button,
  EmptyState,
  Input,
  PageContainer,
  PageHeader,
  Spinner,
} from "../../ui";
import OrderHistory from "./OrderHistory";

export default function CartPage() {
  const [cart, setCart] = useState(null);
  const [showPastOrders, setShowPastOrders] = useState(false);

  const [orders, setOrders] = useState([]);
  const [ordersLoading, setOrdersLoading] = useState(true);
  const [ordersError, setOrdersError] = useState("");

  const [loading, setLoading] = useState(true);
  const [cartError, setCartError] = useState("");

  const [discountCode, setDiscountCode] = useState("");
  const [discountMessage, setDiscountMessage] = useState("");
  const [availableDiscounts, setAvailableDiscounts] = useState([]);

  useEffect(() => {
    loadCart();
    loadDiscounts();
    // loadOrders();
  }, []);

  const loadCart = async () => {
    setLoading(true);

    try {
      const data = await fetchCart();

      console.log("Cart items:", data.items);
      console.log(
        "Cart item IDs:",
        data.items?.map((item) => item.id)
      );

      setCart(data);
      setCartError("");
    } catch (error) {
      console.error("Failed to load cart", error);

      setCartError(
        error.message || "Unable to load your cart. Please try again."
      );
    } finally {
      setLoading(false);
    }
  };

  const loadOrders = async () => {
    setOrdersLoading(true);
    setOrdersError("");

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

      setOrdersError(
        error.message || "Unable to load past orders. Please try again."
      );
    } finally {
      setOrdersLoading(false);
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

  const handlePastOrdersClick = async () => {
  const shouldShowOrders = !showPastOrders;

  setShowPastOrders(shouldShowOrders);

  if (shouldShowOrders) {
    await loadOrders();
  }
};

  if (loading) {
    return (
      <PageContainer size="narrow">
        <Spinner label="Loading your cart…" />
      </PageContainer>
    );
  }

  return (
    <PageContainer size="narrow">
      <PageHeader title="Your Shopping Cart" />

      <div className="lf-cart-history-toggle">
        <Button
          variant="outline"
          onClick={handlePastOrdersClick}
        >
          {showPastOrders ? "← Back to Cart" : "Past Orders"}
        </Button>
      </div>

      {showPastOrders ? (
        <OrderHistory orders={orders} loading={ordersLoading} error={ordersError} />
      ) : cartError ? (
        <Alert>{cartError}</Alert>
      ) : !cart || !cart.items || cart.items.length === 0 ? (
        <EmptyState title="Your cart is empty." />
      ) : (
        <>
          <div className="lf-table-scroll">
            <table className="lf-cart-table">
              <thead>
                <tr>
                  <th>Product</th>
                  <th>Quantity</th>
                  <th>Unit Price</th>
                  <th>Total</th>
                </tr>
              </thead>

              <tbody>
                {cart.items.map((item) => (
                  <tr key={item.id}>
                    <td>{item.product_listing?.product?.name || "Unknown Product"}</td>
                    <td>{item.quantity}</td>
                    <td>${parseFloat(item.unit_price).toFixed(2)}</td>
                    <td>${(item.unit_price * item.quantity).toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="lf-cart-total">
            {availableDiscounts.length > 0 && (
              <div className="lf-cart-promos">
                <strong className="lf-cart-promos__title">
                  🔥 Available Promo Codes:
                </strong>

                <ul className="lf-cart-promos__list">
                  {availableDiscounts.map((discount) => (
                    <li key={discount.id}>
                      Use code{" "}
                      <strong>{discount.code}</strong> for{" "}
                      {parseFloat(discount.percentage)}% off!
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="lf-cart-total__row">
              <span>Subtotal:</span>

              <span>
                ${parseFloat(cart.subtotal).toFixed(2)}
              </span>
            </div>

            {cart.discount_percentage && (
              <div className="lf-cart-total__row lf-cart-total__row--discount">
                <span>
                  Discount Applied (
                  {parseFloat(cart.discount_percentage)}%):
                </span>

                <span>
                  -$
                  {parseFloat(
                    cart.discount_amount
                  ).toFixed(2)}
                </span>
              </div>
            )}

            <div className="lf-cart-total__row lf-cart-total__row--grand">
              <span>Total:</span>

              <span>
                ${parseFloat(cart.total_price).toFixed(2)}
              </span>
            </div>

            <div className="lf-inline-form lf-cart-promo-form">
              <Input
                type="text"
                aria-label="Promo code"
                value={discountCode}
                onChange={(e) =>
                  setDiscountCode(e.target.value)
                }
                placeholder="Enter promo code"
              />

              <Button
                variant="secondary"
                onClick={handleApplyDiscount}
              >
                Apply
              </Button>
            </div>

            {discountMessage && (
              <Alert
                variant={
                  discountMessage.includes("Invalid")
                    ? "error"
                    : "success"
                }
              >
                {discountMessage}
              </Alert>
            )}

            <Button
              onClick={handleCheckout}
              className="lf-button--full lf-cart-checkout"
            >
              Proceed to Checkout
            </Button>
          </div>
        </>
      )}
    </PageContainer>
  );
}
