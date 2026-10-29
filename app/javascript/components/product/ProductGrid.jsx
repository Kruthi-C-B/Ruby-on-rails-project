import React from "react";
import ProductCard from "./ProductCard";

export default function ProductGrid({ products, className = "" }) {
  return (
    <div className={`lf-product-grid${className ? ` ${className}` : ""}`}>
      {products.map((product) => <ProductCard key={product.id} product={product} />)}
    </div>
  );
}
