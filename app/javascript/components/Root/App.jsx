import React from "react";
import { Redirect, Route, Switch } from "react-router-dom";
import CatalogPage from "./CatalogPage";
import ProductPage from "./ProductPage";
import CartPage from "./CartPage";
import StoreOwnerDashboard from "../StoreOwner/StoreOwnerDashboard";
import EditStoreProfile from "../StoreOwner/EditStoreProfile";
import CreateStoreProfile from "../StoreOwner/CreateStoreProfile";
import "./catalog.css";

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