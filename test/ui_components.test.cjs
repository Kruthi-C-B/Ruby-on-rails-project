const assert = require("node:assert/strict");
const { test } = require("node:test");
const path = require("node:path");
const Module = require("node:module");
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const { transformFileSync } = require("@babel/core");

const componentPath = (name) => path.join(__dirname, "..", "app", "javascript", "components", "ui", `${name}.jsx`);

function loadComponent(name) {
  const filename = componentPath(name);
  const { code } = transformFileSync(filename, {
    babelrc: false,
    configFile: false,
    presets: [["@babel/preset-react", { runtime: "automatic" }]],
    plugins: ["@babel/plugin-transform-modules-commonjs"],
  });
  const componentModule = new Module(filename, module);
  componentModule.filename = filename;
  componentModule.paths = Module._nodeModulePaths(path.dirname(filename));
  componentModule._compile(code, filename);
  return componentModule.exports.default;
}

function render(Component, props) {
  return renderToStaticMarkup(React.createElement(Component, props));
}

test("Card composes title, description, body and footer using its visual variant", () => {
  const Card = loadComponent("Card");
  const markup = render(Card, {
    title: "Store information",
    description: "Local shop details",
    variant: "muted",
    footer: "Edit store",
    children: "Store details",
  });

  assert.match(markup, /lf-card--muted/);
  assert.match(markup, /Store information/);
  assert.match(markup, /Local shop details/);
  assert.match(markup, /Store details/);
  assert.match(markup, /Edit store/);
});

test("Button exposes its variant, size, disabled and loading states", () => {
  const Button = loadComponent("Button");
  const markup = render(Button, {
    variant: "danger",
    size: "small",
    disabled: true,
    loading: true,
    children: "Delete",
  });

  assert.match(markup, /lf-button--danger/);
  assert.match(markup, /lf-button--small/);
  assert.match(markup, /disabled=""/);
  assert.match(markup, /aria-busy="true"/);
  assert.match(markup, /Delete/);
});

test("Badge maps known statuses to semantic variants", () => {
  const Badge = loadComponent("Badge");
  assert.match(render(Badge, { children: "Completed" }), /lf-badge--success/);
  assert.match(render(Badge, { children: "ordered" }), /lf-badge--success/);
  assert.match(render(Badge, { children: "Pending" }), /lf-badge--warning/);
  assert.match(render(Badge, { children: "Custom status" }), /lf-badge--neutral/);
});

test("Input associates its label, hint and validation error with the control", () => {
  const Input = loadComponent("Input");
  const markup = render(Input, {
    id: "store-name",
    label: "Store name",
    hint: "Shown to customers",
    error: "Name is required",
    value: "",
    onChange: () => {},
  });

  assert.match(markup, /for="store-name"/);
  assert.match(markup, /id="store-name"/);
  assert.match(markup, /aria-invalid="true"/);
  assert.match(markup, /aria-describedby="store-name-hint store-name-error"/);
  assert.match(markup, /Name is required/);
});

test("Select exposes the same accessible label and validation wiring", () => {
  const Select = loadComponent("Select");
  const markup = render(Select, {
    id: "category",
    label: "Category",
    error: "Choose a category",
    children: React.createElement("option", { value: "food" }, "Food"),
  });

  assert.match(markup, /for="category"/);
  assert.match(markup, /aria-invalid="true"/);
  assert.match(markup, /aria-describedby="category-error"/);
  assert.match(markup, /Food/);
});

test("Alert and EmptyState expose status text and optional actions", () => {
  const Alert = loadComponent("Alert");
  const EmptyState = loadComponent("EmptyState");
  const alert = render(Alert, { variant: "success", children: "Saved" });
  const emptyState = render(EmptyState, {
    title: "No products",
    children: "Add a product to get started.",
    action: React.createElement("button", null, "Add product"),
  });

  assert.match(alert, /role="status"/);
  assert.match(alert, /lf-alert--success/);
  assert.match(alert, /Saved/);
  assert.match(emptyState, /No products/);
  assert.match(emptyState, /Add a product to get started/);
  assert.match(emptyState, /Add product/);
});

test("Modal renders an accessible dialog only when open", () => {
  const Modal = loadComponent("Modal");
  assert.equal(render(Modal, { open: false, title: "Edit store" }), "");

  const markup = render(Modal, {
    open: true,
    title: "Edit store",
    onClose: () => {},
    children: "Store form",
  });

  assert.match(markup, /role="dialog"/);
  assert.match(markup, /aria-modal="true"/);
  assert.match(markup, /aria-labelledby="lf-modal-title"/);
  assert.match(markup, /Edit store/);
  assert.match(markup, /Store form/);
});
