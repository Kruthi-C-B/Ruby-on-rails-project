import React from "react";
import { BrowserRouter } from "react-router-dom";
import App from "./Root/App";

export default function Root(props) {
  return (
    <BrowserRouter>
      <App {...props} />
    </BrowserRouter>
  );
}