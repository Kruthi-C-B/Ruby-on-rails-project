import React from "react";
import { Route, Switch } from "react-router-dom";
import CatalogPage from "./CatalogPage";
import ProductPage from "./ProductPage";
import CartPage from "./CartPage";
import "./catalog.css";

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

      {/* True Catch-all for missing pages */}
      <Route>
        <p>Page not found.</p>
      </Route>
    </Switch>
  );
}