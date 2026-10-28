import React from "react";
import { BrowserRouter, Redirect, Route, Switch } from "react-router-dom";
import CreateStoreProfile from "./CreateStoreProfile";
import EditStoreProfile from "./EditStoreProfile";
import StoreOwnerDashboard from "./StoreOwnerDashboard";

export default function OwnerApp() {
  return (
    <BrowserRouter>
      <Switch>
        <Route exact path="/tenant" component={CreateStoreProfile} />
        <Route exact path="/tenant/edit" component={EditStoreProfile} />
        <Route path="/product_listings" component={StoreOwnerDashboard} />
        <Redirect to="/product_listings" />
      </Switch>
    </BrowserRouter>
  );
}
