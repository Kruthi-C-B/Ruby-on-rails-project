import React from "react";
import ReactDOMClient from "react-dom/client";
import singleSpaReact from "single-spa-react";
import AdminDashboard from "./AdminDashboard";

const lifecycles = singleSpaReact({
  React,
  ReactDOMClient,
  rootComponent: AdminDashboard,
  domElementGetter: () => document.getElementById("admin-dashboard-mfe"),
  errorBoundary: () => <p>The admin dashboard could not load.</p>,
});

export const { bootstrap, mount, unmount } = lifecycles;
