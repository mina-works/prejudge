class ReviewCondition < ApplicationRecord
  belongs_to :artifact

  enum target: {
    students: 0,
    job_seekers: 1,
    local_government_staff: 2,
    companies: 3,
    clients: 4,
    residents: 5,
    internal_members: 6
  }

  enum target: {
    students: 0,
    job_seekers: 1,
    local_government_staff: 2,
    companies: 3,
    clients: 4,
    residents: 5,
    internal_members: 6
  }
end
