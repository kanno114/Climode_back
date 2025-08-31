require 'rails_helper'

RSpec.describe 'Api::V1::Sessions', type: :request do
  describe 'POST /api/v1/signin' do
    context 'メールアドレス認証の場合' do
      let!(:user) { create(:user, email: 'test@example.com', password: 'password123') }
      
      let(:valid_email_params) do
        {
          user: {
            email: 'test@example.com',
            password: 'password123'
          }
        }
      end

      let(:invalid_email_params) do
        {
          user: {
            email: 'test@example.com',
            password: 'wrongpassword'
          }
        }
      end

      let(:non_existent_email_params) do
        {
          user: {
            email: 'nonexistent@example.com',
            password: 'password123'
          }
        }
      end

      context '有効な認証情報の場合' do
        it 'ユーザー情報を返し、200ステータスを返す' do
          post '/api/v1/signin', params: valid_email_params

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response['id']).to eq(user.id)
          expect(json_response['email']).to eq('test@example.com')
          expect(json_response['name']).to eq(user.name)
          expect(json_response['provider']).to eq('email')
        end
      end

      context '無効なパスワードの場合' do
        it '認証エラーを返し、401ステータスを返す' do
          post '/api/v1/signin', params: invalid_email_params

          expect(response).to have_http_status(:unauthorized)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('認証に失敗しました')
          expect(json_response['details']).to eq('メールアドレスまたはパスワードが正しくありません')
        end
      end

      context '存在しないメールアドレスの場合' do
        it '認証エラーを返し、401ステータスを返す' do
          post '/api/v1/signin', params: non_existent_email_params

          expect(response).to have_http_status(:unauthorized)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('認証に失敗しました')
          expect(json_response['details']).to eq('メールアドレスまたはパスワードが正しくありません')
        end
      end
    end

    context 'OAuth認証の場合' do
      let!(:user) { create(:user, email: 'oauth@example.com', name: 'OAuthユーザー') }
      let!(:user_identity) do
        create(:user_identity, 
          user: user, 
          provider: 'google', 
          uid: 'google_12345',
          email: 'oauth@example.com',
          display_name: 'OAuthユーザー'
        )
      end

      let(:valid_oauth_params) do
        {
          user: {
            provider: 'google',
            uid: 'google_12345'
          }
        }
      end

      let(:invalid_oauth_params) do
        {
          user: {
            provider: 'google',
            uid: 'nonexistent_uid'
          }
        }
      end

      context '有効なOAuth認証情報の場合' do
        it 'ユーザー情報を返し、200ステータスを返す' do
          user_identity # 事前に作成
          
          post '/api/v1/signin', params: valid_oauth_params

          expect(response).to have_http_status(:ok)
          
          json_response = JSON.parse(response.body)
          expect(json_response['id']).to eq(user.id)
          expect(json_response['email']).to eq('oauth@example.com')
          expect(json_response['name']).to eq('OAuthユーザー')
          expect(json_response['provider']).to eq('google')
          expect(json_response['uid']).to eq('google_12345')
        end
      end

      context '存在しないOAuth認証情報の場合' do
        it '認証エラーを返し、401ステータスを返す' do
          post '/api/v1/signin', params: invalid_oauth_params

          expect(response).to have_http_status(:unauthorized)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('認証に失敗しました')
          expect(json_response['details']).to eq('OAuthユーザーが見つかりません')
        end
      end

      context 'UserIdentityが存在しない場合' do
        it '認証エラーを返し、401ステータスを返す' do
          post '/api/v1/signin', params: valid_oauth_params

          expect(response).to have_http_status(:unauthorized)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('認証に失敗しました')
          expect(json_response['details']).to eq('OAuthユーザーが見つかりません')
        end
      end
    end

    context 'エラーハンドリング' do
      context 'メール認証で例外が発生した場合' do
        it '500ステータスを返す' do
          allow(User).to receive(:find_by).and_raise(StandardError, 'Database error')
          
          post '/api/v1/signin', params: { user: { email: 'test@example.com', password: 'password123' } }

          expect(response).to have_http_status(:internal_server_error)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('認証処理中にエラーが発生しました')
        end
      end

      context 'OAuth認証で例外が発生した場合' do
        it '500ステータスを返す' do
          allow(UserIdentity).to receive(:includes).and_raise(StandardError, 'Database error')
          
          post '/api/v1/signin', params: { user: { provider: 'google', uid: '12345' } }

          expect(response).to have_http_status(:internal_server_error)
          
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('認証処理中にエラーが発生しました')
        end
      end
    end
  end
end
