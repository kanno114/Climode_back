puts "Seeding users..."

users = [
  { name: "Alice", email: "alice@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Bob", email: "bob@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Carol", email: "carol@example.com", password: "password123", password_confirmation: "password123" },
]

users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(attrs)
  if user.new_record? || user.changed?
    user.save!
    puts "  upserted: #{user.email}"
  else
    puts "  unchanged: #{user.email}"
  end
end

puts "Seed completed."
