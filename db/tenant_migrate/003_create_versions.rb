
# module TenantMigrations
#   class CreateVersions
#     def self.up(connection)
#       connection.create_table(
#         :versions,
#         if_not_exists: true,
#         options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci"
#       ) do |t|
#         t.string :whodunnit
#         t.datetime :created_at
#         t.bigint :item_id, null: false
#         t.string :item_type, limit: 191, null: false
#         t.string :event, null: false
#         t.text :object, limit: 4.gigabytes
#         t.text :object_changes
#       end

#       connection.add_index(
#         :versions,
#         [ :item_type, :item_id ],
#         name: "index_versions_on_item_type_and_item_id",
#         if_not_exists: true
#       )
#     end
#   end
# end


module TenantMigrations
  class CreateVersions
    def self.up(connection)
      connection.create_table(
        :versions,
        if_not_exists: true
      ) do |t|
        t.string :whodunnit
        t.datetime :created_at
        t.bigint :item_id, null: false
        t.string :item_type, limit: 191, null: false
        t.string :event, null: false
        t.text :object, size: :long
        t.text :object_changes, size: :long
      end

      connection.add_index(
        :versions,
        [ :item_type, :item_id ],
        name: "index_versions_on_item_type_and_item_id",
        if_not_exists: true
      )
    end
  end
end
