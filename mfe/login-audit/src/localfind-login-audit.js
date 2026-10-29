import React from "react";
import ReactDOMClient from "react-dom/client";
import singleSpaReact from "single-spa-react";
import LoginAuditLog from "./LoginAuditLog";

const lifecycles = singleSpaReact({
  React,
  ReactDOMClient,
  rootComponent: LoginAuditLog,
  domElementGetter: () => document.getElementById("login-audit-mfe"),
  errorBoundary: () => <p>The login audit could not load.</p>,
});

export const { bootstrap, mount, unmount } = lifecycles;
