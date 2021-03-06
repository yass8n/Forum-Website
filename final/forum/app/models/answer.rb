class Answer < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  has_many :ratings
  has_many :commentarys
  validates :user_id, presence: true
  validates :post_id, presence: true
  validates :answer, presence: true
  before_create :init_rating_score
    def calculate_rating
    ratings = Rating.all.where(answer_id: self.id)
    total = 0
    ratings.each do |rate| 
      total += rate.rate
    end
    return total
  end
  def current_user_rating(current_user, rating)
	return nil if rating.nil?
  	return Rating.where(user_id: current_user.id, answer_id: self.id)[0].rate
  end
  def get_all_answers(post_id)
    answers = Answer.where(post_id: post_id)
    answers = answers.sort_by{|a| (a.rating_score)}
    answers.reverse
  end
  def you_already_answered
    answered = Answer.where(post_id: self.post_id, user_id: self.user_id)[0]
    return true if answered
    return false if !answered
  end
  def find_by_user_id(user_id)
    return Answer.where(user_id: user_id).reverse
  end
  private
  def init_rating_score
  	self.rating_score = 0
  end
end
