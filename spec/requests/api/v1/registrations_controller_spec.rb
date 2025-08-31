require 'rails_helper'

RSpec.describe 'Api::V1::Registrations', type: :request do
  describe 'POST /api/v1/signup' do
    let(:valid_params) do
      {
        user: {
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          name: 'テストユーザー',
          image: 'https://example.com/avatar.jpg'
        }
      }
    end

    let(:invalid_params) do
      {
        user: {
          email: 'invalid-email',
          password: 'short',
          password_confirmation: 'different',
          name: ''
        }
      }
    end

    context '有効なパラメータの場合' do
      it 'ユーザーを作成し、201ステータスを返す' do
        post '/api/v1/signup', params: valid_params
        
        puts "Response status: #{response.status}"
        puts "Response body: #{response.body}"
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['email']).to eq('test@example.com')
        expect(json_response['name']).to eq('テストユーザー')
        expect(json_response['image']).to eq('https://example.com/avatar.jpg')
        expect(json_response['id']).to be_present
      end

      it 'パスワードを正しくハッシュ化する' do
        post '/api/v1/signup', params: valid_params
        
        user = User.find_by(email: 'test@example.com')
        expect(user.authenticate('password123')).to be_truthy
        expect(user.authenticate('wrongpassword')).to be_falsey
      end
    end

    context '無効なパラメータの場合' do
      it 'ユーザーを作成せず、422ステータスを返す' do
        expect {
          post '/api/v1/signup', params: invalid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end

      it '重複したメールアドレスの場合はエラーを返す' do
        create(:user, email: 'test@example.com')
        
        expect {
          post '/api/v1/signup', params: valid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Email has already been taken')
      end
    end
  end

  describe 'POST /api/v1/oauth_register' do
    let(:valid_oauth_params) do
      {
        user: {
          email: 'oauth@example.com',
          name: 'OAuthユーザー',
          image: 'https://example.com/oauth-avatar.jpg',
          provider: 'google',
          uid: 'google_12345'
        }
      }
    end

    let(:invalid_oauth_params) do
      {
        user: {
          email: '',
          name: '',
          provider: 'google',
          uid: ''
        }
      }
    end

    context '有効なOAuthパラメータの場合' do
      it 'ユーザーとUserIdentityを作成し、200ステータスを返す' do
        expect {
          post '/api/v1/oauth_register', params: valid_oauth_params
        }.to change(User, :count).by(1).and change(UserIdentity, :count).by(1)

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('ok')
        expect(json_response['id']).to be_present
      end

      it '既存のユーザーの場合は更新する' do
        existing_user = create(:user, email: 'oauth@example.com', name: '古い名前')
        
        expect {
          post '/api/v1/oauth_register', params: valid_oauth_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:ok)
        
        existing_user.reload
        expect(existing_user.name).to eq('OAuthユーザー')
        expect(existing_user.image).to eq('https://example.com/oauth-avatar.jpg')
      end

      it 'UserIdentityを正しく作成する' do
        post '/api/v1/oauth_register', params: valid_oauth_params
        
        user = User.find_by(email: 'oauth@example.com')
        user_identity = user.user_identities.first
        
        expect(user_identity.provider).to eq('google')
        expect(user_identity.uid).to eq('google_12345')
        expect(user_identity.email).to eq('oauth@example.com')
        expect(user_identity.display_name).to eq('OAuthユーザー')
      end
    end

    context '無効なOAuthパラメータの場合' do
      it 'ユーザーを作成せず、422ステータスを返す' do
        expect {
          post '/api/v1/oauth_register', params: invalid_oauth_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'UserIdentityの作成に失敗した場合' do
      it 'ロールバックして422ステータスを返す' do
        # UserIdentityの作成を強制的に失敗させる
        allow_any_instance_of(UserIdentity).to receive(:save).and_return(false)
        
        expect {
          post '/api/v1/oauth_register', params: valid_oauth_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Failed to create user identity')
      end
    end
  end
end
