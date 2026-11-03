import React from "react";
import { Button, Card, EmptyState, Input } from "./ui";
import { actionButtonsStyle, inlineFormStyle, inputStyle, listItemStyle, listStyle, mutedStyle } from "./adminTabStyles";

export default function CategoriesTab({
  categories,
  loading,
  editingRecord,
  setEditingRecord,
  changeEditingField,
  handleSubmit,
  handleUpdate,
  handleDelete,
}) {
  return (
    <>
      <Card as="section" className="lf-admin-panel">
        <h2>Existing Categories ({categories.length})</h2>
        {!loading && categories.length === 0 && <EmptyState title="No categories found yet." />}

        {categories.length > 0 && (
          <ul style={listStyle}>
            {categories.map((category) => (
              <li key={category.id} style={listItemStyle}>
                {editingRecord?.type === "category" && editingRecord.id === category.id ? (
                  <form
                    onSubmit={(event) => handleUpdate(
                      event,
                      "categories",
                      { category: { name: editingRecord.name.trim() } },
                      "categories"
                    )}
                    style={inlineFormStyle}
                  >
                    <input
                      aria-label={`Category ${category.id} name`}
                      value={editingRecord.name}
                      onChange={(event) => changeEditingField("name", event.target.value)}
                      required
                      style={inputStyle}
                    />
                    <Button type="submit" size="small">Save</Button>
                    <Button type="button" variant="outline" size="small" onClick={() => setEditingRecord(null)}>Cancel</Button>
                  </form>
                ) : (
                  <>
                    <span><strong>{category.name}</strong> <span style={mutedStyle}>ID: {category.id}</span></span>
                    <div style={actionButtonsStyle}>
                      <Button
                        type="button"
                        variant="outline"
                        size="small"
                        onClick={() => setEditingRecord({ type: "category", id: category.id, name: category.name })}
                      >
                        Edit
                      </Button>
                      <Button
                        type="button"
                        variant="danger"
                        size="small"
                        onClick={() => handleDelete("categories", category.id, "categories", "category")}
                      >
                        Delete
                      </Button>
                    </div>
                  </>
                )}
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card as="section" className="lf-admin-panel">
        <h2>Add New Category</h2>
        <form
          onSubmit={(event) => handleSubmit(
            event,
            "categories",
            { category: { name: event.currentTarget.name.value.trim() } },
            "categories"
          )}
        >
          <Input
            label="Category Name"
            name="name"
            required
            style={inputStyle}
            placeholder="e.g. Electronics, Home Goods"
          />
          <Button type="submit" size="large">Create Category</Button>
        </form>
      </Card>
    </>
  );
}
