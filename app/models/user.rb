class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :uvisits
  has_many :shops, through: :viisits

  has_many :likes, dependent: :destroy
  has_many :liked_posts, through: :likes, source: :posts

  has_one :profile, dependent: :destroy
  after_create :create_profile

  has_many :comments

  has_many :relationships, class_name: "Relationship", foreign_key: "follower_id", dependent: :destroy
  has_many :reverse_of_relationships, class_name: "Relationship", foreign_key: "followed_id", dependent: :destroy
  has_many :followings, through: :relationships, source: :followed
  has_many :followers, through: :reverse_of_relationships, source: :follower

  def follow(user_name)
    user = User.find_by(name: user_name)
    relationships.create(followed_id: user.id)
  end

  def unfollow(user_name)
    user = User.find_by(name: user_name)
    relationships.find_by(followed_id: user.id).destroy
  end

  def following?(user)
    followings.include?(user)
  end


  validates :name, presence: true
  validates :agreement_terms, acceptance: { accept: true, on: :create }
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :timeoutable, :confirmable, :omniauthable,
         omniauth_providers: [:twitter]

  # OmniAuth認証データを元にデータベースでユーザーを探す。なければ新しく作る。
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.provider = auth.provider
      user.uid      = auth.uid
      user.name = auth.info.nickname
      # パスワード不要なので、パスワードには触らない。
    end
  end

  # session["devise.user_attributes"]が存在する場合、それとparamsを組み合わせてUser.newできるよう、Deviseの実装をOverrideする。
  def self.new_with_session(params, session)
    if session["devise.user_attributes"]
      new(session["devise.user_attributes"]) do |user|
        user.attributes = params
        user.valid?
      end
    else
      super
    end
  end

  # ログイン時、OmniAuthで認証したユーザーのパスワード入力免除するため、Deviseの実装をOverrideする。
  def password_required?
    super && provider.blank? # provider属性に値があればパスワード入力免除
  end

  # Edit時、OmniAuthで認証したユーザーのパスワード入力免除するため、Deviseの実装をOverrideする。
  def update_with_password(params, *options)
    if encrypted_password.blank? # encrypted_password属性が空の場合
      update(params, *options) # パスワード入力なしにデータ更新
    else
      super
    end
  end
end
