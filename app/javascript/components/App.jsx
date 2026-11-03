import React from "react";
import { Redirect, Route, Switch } from "react-router-dom";
import CatalogPage from "./pages/shop/CatalogPage";
import ProductPage from "./pages/shop/ProductPage";
import CartPage from "./pages/shop/CartPage";
import StoreOwnerDashboard from "./pages/store-owner/StoreOwnerDashboard";
import EditStoreProfile from "./pages/store-owner/EditStoreProfile";
import CreateStoreProfile from "./pages/store-owner/CreateStoreProfile";
import "./pages/shop/catalog.css";

export default function App({ storeName }) {
  return (
    <Switch>
      <Route exact path={["/localFind", "/localFind/products"]}>
        <CatalogPage storeName={storeName} />
      </Route>

      <Route exact path="/localFind/products/:id">
        <ProductPage />
      </Route>

      <Route exact path="/localFind/cart">
        <CartPage />
      </Route>

      <Route exact path="/localFind/product_listings">
        <StoreOwnerDashboard />
      </Route>

      <Route exact path="/localFind/tenant">
        <CreateStoreProfile />
      </Route>

      <Route exact path="/localFind/tenant/edit">
        <EditStoreProfile />
      </Route>

      <Route exact path="/admin/dashboard">
        <Redirect to="/localFind/admin/dashboard" />
      </Route>

      <Route>
        <p>Page not found.</p>
      </Route>
    </Switch>
  );
}