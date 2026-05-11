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

  enum tone: {
    serious: 0,
    friendly: 1,
    warm: 2,
    professional: 3,
    modern: 4,
    casual: 5,
    luxurious: 6
  }
end
