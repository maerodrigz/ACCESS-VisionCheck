import { apiRequest, apiUpload } from './client'

import { mediaUrl } from './media'



export interface ChangePasswordPayload {

  current_password: string

  new_password: string

}



export interface ProfileData {

  id: number

  name: string

  email: string

  role: string

  profile_image: string | null

}



export async function fetchProfile(): Promise<ProfileData> {

  return apiRequest<ProfileData>('/profile')

}



export function profileImageUrl(profile: Pick<ProfileData, 'profile_image'> | null | undefined): string | null {

  if (!profile?.profile_image) return null

  const url = mediaUrl(profile.profile_image)

  return url || null

}



export interface UpdateProfilePayload {
  name?: string
  email?: string
  contact_number?: string
}

export async function updateProfile(payload: UpdateProfilePayload): Promise<ProfileData> {
  return apiRequest<ProfileData>('/profile', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}

export async function changePassword(payload: ChangePasswordPayload): Promise<void> {
  await apiRequest('/profile', {
    method: 'PATCH',
    body: JSON.stringify(payload),
  })
}



export async function uploadProfileAvatar(file: File): Promise<ProfileData> {

  return apiUpload<ProfileData>('/profile/avatar', file)

}


