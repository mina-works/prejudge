# Users
User.find_or_create_by!(email: "reviewer1@example.com") do |user|
  user.name = "Reviewer1"
end

User.find_or_create_by!(email: "reviewer2@example.com") do |user|
  user.name = "Reviewer2"
end

User.find_or_create_by!(email: "reviewer3@example.com") do |user|
  user.name = "Reviewer3"
end

User.find_or_create_by!(email: "approver@example.com") do |user|
  user.name = "Approver"
end