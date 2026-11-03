import React from "react";
import { Button, Card, EmptyState, Input, Select } from "./ui";
import { actionButtonsStyle, cellStyle, inputStyle, tableStyle, tableWrapperStyle } from "./adminTabStyles";

export default function ProductsTab({
  products,
  categories,
  loading,
  selectedProductCategory,
  setSelectedProductCategory,
  editingRecord,
  setEditingRecord,
  changeEditingField,
  handleSubmit,
  handleUpdate,
  handleDelete,
}) {
  const visibleGroups = selectedProductCategory === null
    ? products
    : products.filter((group) => String(group.category_id) === String(selectedProductCategory));
  const categoryOptions = categories.length > 0
    ? categories
    : products.map(({ category_id, category_name }) => ({ id: category_id, name: category_name }));
  const productCount = products.reduce((total, group) => total + group.products.length, 0);

  return (
    <>
      <Card as="section" className="lf-admin-panel">
        <h2>Existing Universal Products ({productCount})</h2>
        <div className="lf-category-filter" role="group" aria-label="Filter products by category">
          <Button
            type="button"
            size="small"
            variant={selectedProductCategory === null ? "primary" : "secondary"}
            aria-pressed={selectedProductCategory === null}
            onClick={() => setSelectedProductCategory(null)}
          >
            All categories
          </Button>
          {categoryOptions.map((category) => (
            <Button
              key={category.id}
              type="button"
              size="small"
              variant={String(selectedProductCategory) === String(category.id) ? "primary" : "secondary"}
              aria-pressed={String(selectedProductCategory) === String(category.id)}
              onClick={() => setSelectedProductCategory(category.id)}
            >
              {category.name}
            </Button>
          ))}
        </div>

        {!loading && products.length === 0 && <EmptyState title="No products found yet." />}
        {visibleGroups.map((group) => (
          <div key={group.category_id} style={{ marginTop: 24 }}>
            <h3>{group.category_name}</h3>
            <div style={tableWrapperStyle}>
              <table style={tableStyle}>
                <thead>
                  <tr>
                    <th style={cellStyle}>ID</th>
                    <th style={cellStyle}>Product</th>
                    <th style={cellStyle}>Description</th>
                    <th style={cellStyle}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {group.products.map((product) => (
                    <tr key={product.id}>
                      <td style={cellStyle}>{product.id}</td>
                      {editingRecord?.type === "product" && editingRecord.id === product.id ? (
                        <>
                          <td style={cellStyle}>
                            <input
                              aria-label={`Product ${product.id} name`}
                              value={editingRecord.name}
                              onChange={(event) => changeEditingField("name", event.target.value)}
                              required
                              style={inputStyle}
                            />
                            <select
                              aria-label={`Product ${product.id} category`}
                              value={editingRecord.category_id}
                              onChange={(event) => changeEditingField("category_id", event.target.value)}
                              required
                              style={{ ...inputStyle, marginTop: 8 }}
                            >
                              {categories.map((category) => (
                                <option key={category.id} value={category.id}>{category.name}</option>
                              ))}
                            </select>
                          </td>
                          <td style={cellStyle}>
                            <textarea
                              aria-label={`Product ${product.id} description`}
                              value={editingRecord.description}
                              onChange={(event) => changeEditingField("description", event.target.value)}
                              required
                              rows="3"
                              style={inputStyle}
                            />
                          </td>
                          <td style={cellStyle}>
                            <form
                              onSubmit={(event) => handleUpdate(
                                event,
                                "products",
                                {
                                  product: {
                                    name: editingRecord.name.trim(),
                                    description: editingRecord.description.trim(),
                                    category_id: editingRecord.category_id,
                                  },
                                },
                                "products"
                              )}
                              style={actionButtonsStyle}
                            >
                              <Button type="submit" size="small">Save</Button>
                              <Button type="button" variant="outline" size="small" onClick={() => setEditingRecord(null)}>Cancel</Button>
                            </form>
                          </td>
                        </>
                      ) : (
                        <>
                          <td style={cellStyle}><strong>{product.name}</strong></td>
                          <td style={cellStyle}>{product.description || "—"}</td>
                          <td style={cellStyle}>
                            <div style={actionButtonsStyle}>
                              <Button
                                type="button"
                                variant="outline"
                                size="small"
                                onClick={() => setEditingRecord({
                                  type: "product",
                                  id: product.id,
                                  name: product.name,
                                  description: product.description || "",
                                  category_id: group.category_id,
                                })}
                              >
                                Edit
                              </Button>
                              <Button
                                type="button"
                                variant="danger"
                                size="small"
                                onClick={() => handleDelete("products", product.id, "products", "product")}
                              >
                                Delete
                              </Button>
                            </div>
                          </td>
                        </>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ))}
        {!loading && products.length > 0 && visibleGroups.length === 0 && (
          <EmptyState title="No products in this category yet." />
        )}
      </Card>

      <Card as="section" className="lf-admin-panel">
        <h2>Add Universal Product Base</h2>
        <form
          onSubmit={(event) => handleSubmit(
            event,
            "products",
            {
              product: {
                name: event.currentTarget.name.value.trim(),
                description: event.currentTarget.desc.value.trim(),
                category_id: event.currentTarget.category_id.value,
              },
            },
            "products"
          )}
        >
          <Input label="Product Name" name="name" required style={inputStyle} placeholder="e.g. iPhone 15" />
          <Input
            as="textarea"
            label="Description"
            name="desc"
            required
            style={inputStyle}
            rows="3"
            placeholder="Product description..."
          />
          <Select label="Category" name="category_id" required style={inputStyle} defaultValue="">
            <option value="">Select a Category...</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>{category.name}</option>
            ))}
          </Select>
          <Button type="submit" size="large">Create Product Base</Button>
        </form>
      </Card>
    </>
  );
}
