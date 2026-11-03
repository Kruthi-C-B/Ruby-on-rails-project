import React, { useState } from "react";
import { fetchRequest } from "./api";
import CategoriesTab from "./CategoriesTab";
import DiscountsTab from "./DiscountsTab";
import ProductsTab from "./ProductsTab";
import StoreAudit from "./StoreAudit";
import SecurityLogsMicrofrontend from "./SecurityLogsMicrofrontend";
import useApi from "./useApi";
import { Alert, Button, PageContainer, PageHeader, Spinner } from "./ui";
import "./admin.css";

const tabEndpoints = {
  categories: "/api/v1/admin/categories",
  products: "/api/v1/admin/products",
  discounts: "/api/v1/admin/discounts",
};

const tabs = [
  ["categories", "Categories"],
  ["products", "Universal Products"],
  ["discounts", "Global Discounts"],
  ["security", "Security Logs"],
  ["audit", "Store Audit"],
];

const tabsStyle = {
  display: "flex",
  gap: 10,
  flexWrap: "wrap",
  margin: "20px 0",
};

function validateProducts(data) {
  if (!Array.isArray(data) || data.some((group) => !group || !Array.isArray(group.products))) {
    throw new Error("Products API returned an invalid response. Please retry or contact support.");
  }
  return data;
}

export default function AdminDashboard({
  adminApiUrl,
  securityLogsMfeUrl,
  securityLogsApiUrl,
}) {
  const [activeTab, setActiveTab] = useState("categories");
  const [message, setMessage] = useState(null);
  const [selectedProductCategory, setSelectedProductCategory] = useState(null);
  const [editingRecord, setEditingRecord] = useState(null);

  const categoriesApi = useApi(tabEndpoints.categories, adminApiUrl, {
    enabled: activeTab === "categories",
    initialData: [],
  });
  const productsApi = useApi(tabEndpoints.products, adminApiUrl, {
    enabled: activeTab === "products",
    initialData: [],
    validate: validateProducts,
  });
  const discountsApi = useApi(tabEndpoints.discounts, adminApiUrl, {
    enabled: activeTab === "discounts",
    initialData: [],
  });

  const apis = {
    categories: categoriesApi,
    products: productsApi,
    discounts: discountsApi,
  };
  const activeApi = apis[activeTab];
  const categories = categoriesApi.data;
  const products = productsApi.data;
  const discounts = discountsApi.data;

  const loadData = (tab) => apis[tab]?.reload();

  const handleSubmit = async (event, endpoint, payload, tab) => {
    event.preventDefault();
    setMessage(null);

    try {
      await fetchRequest(`/api/v1/admin/${endpoint}`, "POST", payload, adminApiUrl);
      setMessage({ type: "success", text: `Successfully created ${endpoint}!` });
      event.target.reset();
      loadData(tab);
    } catch (error) {
      setMessage({ type: "error", text: error.message || `Failed to create ${endpoint}.` });
    }
  };

  const handleUpdate = async (event, endpoint, payload, tab) => {
    event.preventDefault();
    setMessage(null);

    try {
      await fetchRequest(`/api/v1/admin/${endpoint}/${editingRecord.id}`, "PATCH", payload, adminApiUrl);
      setEditingRecord(null);
      setMessage({ type: "success", text: `Successfully updated ${endpoint.slice(0, -1)}.` });
      loadData(tab);
    } catch (error) {
      setMessage({ type: "error", text: error.message || `Failed to update ${endpoint}.` });
    }
  };

  const handleDelete = async (endpoint, id, tab, label) => {
    if (!window.confirm(`Delete this ${label}? This action cannot be undone.`)) return;
    setMessage(null);

    try {
      await fetchRequest(`/api/v1/admin/${endpoint}/${id}`, "DELETE", undefined, adminApiUrl);
      setEditingRecord(null);
      setMessage({ type: "success", text: `Successfully deleted ${label}.` });
      loadData(tab);
    } catch (error) {
      setMessage({ type: "error", text: error.message || `Failed to delete ${label}.` });
    }
  };

  const changeEditingField = (field, value) => {
    setEditingRecord((current) => ({ ...current, [field]: value }));
  };

  return (
    <PageContainer className="lf-admin-dashboard">
      <PageHeader title="Platform Admin Dashboard" />
      <div style={tabsStyle}>
        {tabs.map(([key, label]) => (
          <Button
            key={key}
            onClick={() => {
              setActiveTab(key);
              setMessage(null);
            }}
            variant={activeTab === key ? "primary" : "secondary"}
            aria-pressed={activeTab === key}
          >
            {label}
          </Button>
        ))}
      </div>

      {message && <Alert variant={message.type}>{message.text}</Alert>}
      {activeApi?.error && (
        <Alert>
          {activeApi.error}
          <Button
            variant="outline"
            size="small"
            onClick={() => loadData(activeTab)}
            style={{ marginLeft: 12 }}
          >
            Retry
          </Button>
        </Alert>
      )}
      {activeApi?.loading && <Spinner label="Loading existing records…" />}

      {activeTab === "categories" && (
        <CategoriesTab
          categories={categories}
          loading={categoriesApi.loading}
          editingRecord={editingRecord}
          setEditingRecord={setEditingRecord}
          changeEditingField={changeEditingField}
          handleSubmit={handleSubmit}
          handleUpdate={handleUpdate}
          handleDelete={handleDelete}
        />
      )}
      {activeTab === "products" && (
        <ProductsTab
          products={products}
          categories={categories}
          loading={productsApi.loading}
          selectedProductCategory={selectedProductCategory}
          setSelectedProductCategory={setSelectedProductCategory}
          editingRecord={editingRecord}
          setEditingRecord={setEditingRecord}
          changeEditingField={changeEditingField}
          handleSubmit={handleSubmit}
          handleUpdate={handleUpdate}
          handleDelete={handleDelete}
        />
      )}
      {activeTab === "discounts" && (
        <DiscountsTab
          discounts={discounts}
          loading={discountsApi.loading}
          editingRecord={editingRecord}
          setEditingRecord={setEditingRecord}
          changeEditingField={changeEditingField}
          handleSubmit={handleSubmit}
          handleUpdate={handleUpdate}
          handleDelete={handleDelete}
        />
      )}
      {activeTab === "security" && (
        <SecurityLogsMicrofrontend
          securityLogsApiUrl={securityLogsApiUrl}
          mfeUrl={securityLogsMfeUrl}
        />
      )}
      {activeTab === "audit" && <StoreAudit adminApiUrl={adminApiUrl} />}
    </PageContainer>
  );
}
