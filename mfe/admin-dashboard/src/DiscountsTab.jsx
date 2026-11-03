import React from "react";
import { Button, Card, EmptyState, Input } from "./ui";
import { actionButtonsStyle, cellStyle, inputStyle, tableStyle, tableWrapperStyle } from "./adminTabStyles";

export default function DiscountsTab({
  discounts,
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
        <h2>Existing Global Discounts ({discounts.length})</h2>
        {!loading && discounts.length === 0 && <EmptyState title="No discount codes found yet." />}
        {discounts.length > 0 && (
          <div style={tableWrapperStyle}>
            <table style={tableStyle}>
              <thead>
                <tr>
                  <th style={cellStyle}>ID</th>
                  <th style={cellStyle}>Code</th>
                  <th style={cellStyle}>Percentage Off</th>
                  <th style={cellStyle}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {discounts.map((discount) => (
                  <tr key={discount.id}>
                    <td style={cellStyle}>{discount.id}</td>
                    {editingRecord?.type === "discount" && editingRecord.id === discount.id ? (
                      <>
                        <td style={cellStyle}>
                          <input
                            aria-label={`Discount ${discount.id} code`}
                            value={editingRecord.code}
                            onChange={(event) => changeEditingField("code", event.target.value)}
                            required
                            style={inputStyle}
                          />
                        </td>
                        <td style={cellStyle}>
                          <input
                            aria-label={`Discount ${discount.id} percentage`}
                            type="number"
                            min="0.1"
                            max="100"
                            step="0.1"
                            value={editingRecord.percentage}
                            onChange={(event) => changeEditingField("percentage", event.target.value)}
                            required
                            style={inputStyle}
                          />
                        </td>
                        <td style={cellStyle}>
                          <form
                            onSubmit={(event) => handleUpdate(
                              event,
                              "discounts",
                              {
                                discount: {
                                  code: editingRecord.code.trim(),
                                  percentage: editingRecord.percentage,
                                },
                              },
                              "discounts"
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
                        <td style={cellStyle}><strong>{discount.code}</strong></td>
                        <td style={cellStyle}>{discount.percentage}%</td>
                        <td style={cellStyle}>
                          <div style={actionButtonsStyle}>
                            <Button
                              type="button"
                              variant="outline"
                              size="small"
                              onClick={() => setEditingRecord({
                                type: "discount",
                                id: discount.id,
                                code: discount.code,
                                percentage: discount.percentage,
                              })}
                            >
                              Edit
                            </Button>
                            <Button
                              type="button"
                              variant="danger"
                              size="small"
                              onClick={() => handleDelete("discounts", discount.id, "discounts", "discount")}
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
        )}
      </Card>

      <Card as="section" className="lf-admin-panel">
        <h2>Create Global Discount Code</h2>
        <form
          onSubmit={(event) => handleSubmit(
            event,
            "discounts",
            {
              discount: {
                code: event.currentTarget.code.value.trim(),
                percentage: event.currentTarget.percentage.value,
              },
            },
            "discounts"
          )}
        >
          <Input label="Promo Code" name="code" required style={inputStyle} placeholder="e.g. BLACKFRIDAY20" />
          <Input
            label="Percentage Off"
            name="percentage"
            type="number"
            min="0.1"
            max="100"
            step="0.1"
            required
            style={inputStyle}
            placeholder="e.g. 20"
          />
          <Button type="submit" size="large">Create Discount</Button>
        </form>
      </Card>
    </>
  );
}
