# 1. Create the Hardcoded Platform Admin
User.find_or_create_by!(email: "admin@localfind.com") do |user|
  user.password = "secret123"
  user.password_confirmation = "secret123"
  user.platform_admin = true
end
puts "Platform Admin created: admin@localfind.com / secret123"

# 2. Define Categories and their associated Products
catalog_data = {
  "Electronics" => [
    { name: "Wireless Headphones", description: "Noise-cancelling over-ear headphones." },
    { name: "Smartphone 5G", description: "Latest model with a high-resolution camera and OLED display." },
    { name: "Ultra-thin Laptop", description: "14-inch thin and light laptop for professionals." }
  ],
  "Clothing" => [
    { name: "Classic Cotton T-Shirt", description: "100% organic cotton plain t-shirt in various colors." },
    { name: "Denim Jeans", description: "Classic straight-leg blue jeans." },
    { name: "Winter Puffer Jacket", description: "Water-resistant insulated jacket for cold weather." }
  ],
  "Home Goods" => [
    { name: "Ceramic Coffee Mug", description: "12oz handmade ceramic mug." },
    { name: "Fleece Throw Blanket", description: "Soft and warm fleece blanket for the couch." },
    { name: "LED Desk Lamp", description: "Desk lamp with adjustable brightness and color temperature." }
  ],
  "Groceries" => [
    { name: "Organic Gala Apples", description: "1 lb bag of fresh organic apples." },
    { name: "Whole Wheat Bread", description: "Freshly baked whole grain loaf." },
    { name: "Almond Milk", description: "Unsweetened vanilla almond milk, 1 Liter." }
  ]
}

# 3. Loop through the data to create Categories and Products
catalog_data.each do |category_name, products_data|
  # Find or create the category
  category = Category.find_or_create_by!(name: category_name)

  # Find or create the products under that category
  products_data.each do |product_data|
    Product.find_or_create_by!(name: product_data[:name]) do |product|
      product.category = category
      product.description = product_data[:description]
    end
  end
end

puts "Categories and Products created successfully!"
