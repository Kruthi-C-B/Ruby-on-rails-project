import React from "react";
import ReactDOMClient from "react-dom/client";
import singleSpaReact from "single-spa-react";
import SecurityLogs from "./SecurityLogs";

const lifecycles = singleSpaReact({
  React,
  ReactDOMClient,
  rootComponent: SecurityLogs,
  domElementGetter: (props) => props.domElement,
  errorBoundary: () => React.createElement(
    "p",
    { role: "alert" },
    "Security logs could not be displayed."
  ),
});

export const { bootstrap, mount, unmount } = lifecycles;
