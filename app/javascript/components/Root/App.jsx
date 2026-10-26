import React from "react";
import { Route, Switch } from "react-router-dom";
import CatalogPage from "./CatalogPage";
import ProductPage from "./ProductPage";
import CartPage from "./CartPage";
import AdminDashboard from "../Admin/AdminDashboard";
import StoreOwnerDashboard from "../StoreOwner/StoreOwnerDashboard"; // <-- Add this import
import EditStoreProfile from "../StoreOwner/EditStoreProfile";
import "./catalog.css";
import CreateStoreProfile from "../StoreOwner/CreateStoreProfile";

export default function App({ storeName }) {
  return (
    <Switch>
      <Route exact path={["/", "/products"]}>
        <CatalogPage storeName={storeName} />
      </Route>
      <Route path="/products/:id">
        <ProductPage />
      </Route>
      <Route path="/cart">
        <CartPage />
      </Route>
      
      {/* Explicit route for Store Owners */}
      <Route path="/product_listings">
        <StoreOwnerDashboard />
      </Route>

       <Route exact path="/tenant">
        <CreateStoreProfile />
      </Route>

      <Route path="/tenant/edit">
         <EditStoreProfile />
      </Route>

      {/* Explicit route for Platform Admin */}
      <Route path="/admin/dashboard">
        <AdminDashboard />
      </Route>

      {/* True Catch-all for missing pages */}
      <Route>
        <p>Page not found.</p>
      </Route>
    </Switch>
  );
}