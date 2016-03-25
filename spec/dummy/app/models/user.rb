class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :trackable, :validatable, :authentication_keys => [:email]

  acts_as_addressable :billing, :shipping

  def to_s
    email
  end

  def phone
    '555-555-5555'
  end

end
