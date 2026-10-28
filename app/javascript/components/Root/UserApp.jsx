import React from "react";
import { BrowserRouter } from "react-router-dom";
import App from "./App";

export default function UserApp(props) {
  return (
    <BrowserRouter>
      <App {...props} />
    </BrowserRouter>
  );
}
