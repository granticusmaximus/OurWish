import { useState } from 'react'
import type { ChangeEvent, FormEvent } from 'react'
import { api, ApiError } from '../api/client'
import { useAuth } from '../auth/AuthContext'
import { Modal } from './Modal'

// Mirrors macos/OurWish/OurWish/Views/Profile/ProfileView.swift: profile fields +
// photo, change password, and delete account, in one modal.
export function ProfileModal({ onClose }: { onClose: () => void }) {
  const { currentUser, updateProfile, deleteAccount } = useAuth()

  const [firstName, setFirstName] = useState(currentUser?.firstName ?? '')
  const [lastName, setLastName] = useState(currentUser?.lastName ?? '')
  const [displayName, setDisplayName] = useState(currentUser?.displayName ?? '')
  const [email, setEmail] = useState(currentUser?.email ?? '')
  const [bio, setBio] = useState(currentUser?.bio ?? '')
  const [imageBase64, setImageBase64] = useState<string | null>(null)
  const [imagePreviewURL, setImagePreviewURL] = useState<string | null>(currentUser?.imageURL ?? null)
  const [profileError, setProfileError] = useState<string | null>(null)
  const [profileSuccess, setProfileSuccess] = useState<string | null>(null)
  const [isSavingProfile, setIsSavingProfile] = useState(false)

  const [currentPassword, setCurrentPassword] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [passwordError, setPasswordError] = useState<string | null>(null)
  const [passwordSuccess, setPasswordSuccess] = useState<string | null>(null)
  const [isChangingPassword, setIsChangingPassword] = useState(false)

  const [deleteError, setDeleteError] = useState<string | null>(null)
  const [isDeleting, setIsDeleting] = useState(false)

  const isProfileValid =
    firstName.trim() !== '' && lastName.trim() !== '' && displayName.trim() !== '' && email.trim() !== ''

  const handlePhotoChange = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => {
      const result = reader.result as string
      // "data:image/png;base64,AAAA..." — the server only wants the base64 payload.
      const base64 = result.split(',')[1] ?? null
      setImageBase64(base64)
      setImagePreviewURL(result)
    }
    reader.readAsDataURL(file)
  }

  const handleSaveProfile = async (event: FormEvent) => {
    event.preventDefault()
    setIsSavingProfile(true)
    setProfileError(null)
    try {
      await updateProfile({
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        displayName: displayName.trim(),
        email: email.trim(),
        bio: bio.trim() ? bio.trim() : null,
        imageBase64,
      })
      setProfileSuccess('Profile updated')
    } catch (error) {
      setProfileError(error instanceof ApiError ? error.message : 'Could not update profile')
      setProfileSuccess(null)
    } finally {
      setIsSavingProfile(false)
    }
  }

  const handleChangePassword = async (event: FormEvent) => {
    event.preventDefault()
    if (newPassword !== confirmPassword) {
      setPasswordError("New passwords don't match")
      setPasswordSuccess(null)
      return
    }

    setIsChangingPassword(true)
    setPasswordError(null)
    try {
      await api.changePassword(currentPassword, newPassword)
      setPasswordSuccess('Password updated')
      setCurrentPassword('')
      setNewPassword('')
      setConfirmPassword('')
    } catch (error) {
      setPasswordError(error instanceof ApiError ? error.message : 'Could not update password')
      setPasswordSuccess(null)
    } finally {
      setIsChangingPassword(false)
    }
  }

  const handleDeleteAccount = async () => {
    if (!confirm('Permanently delete your account, your wish lists, and any lists shared with a partner? This can\'t be undone.')) {
      return
    }
    setIsDeleting(true)
    setDeleteError(null)
    try {
      await deleteAccount()
    } catch (error) {
      setDeleteError(error instanceof ApiError ? error.message : 'Could not delete account')
      setIsDeleting(false)
    }
  }

  return (
    <Modal title="Edit Profile" onClose={onClose}>
      <form onSubmit={handleSaveProfile}>
        {profileError && <p className="error-text">{profileError}</p>}
        {profileSuccess && <p className="success-text">{profileSuccess}</p>}

        <div className="field">
          <label htmlFor="profile-photo">Photo</label>
          <div className="name-row-2" style={{ alignItems: 'center' }}>
            {imagePreviewURL ? (
              <img
                className="account-avatar"
                style={{ width: 56, height: 56 }}
                src={imagePreviewURL}
                alt=""
              />
            ) : (
              <span className="account-avatar account-avatar-fallback" style={{ width: 56, height: 56 }}>
                👤
              </span>
            )}
            <input id="profile-photo" type="file" accept="image/*" onChange={handlePhotoChange} />
          </div>
        </div>

        <div className="name-row-2">
          <div className="field">
            <label htmlFor="profile-first-name">First Name</label>
            <input id="profile-first-name" value={firstName} onChange={(event) => setFirstName(event.target.value)} required />
          </div>
          <div className="field">
            <label htmlFor="profile-last-name">Last Name</label>
            <input id="profile-last-name" value={lastName} onChange={(event) => setLastName(event.target.value)} required />
          </div>
        </div>

        <div className="field">
          <label htmlFor="profile-display-name">Display Name</label>
          <input
            id="profile-display-name"
            value={displayName}
            onChange={(event) => setDisplayName(event.target.value)}
            required
          />
        </div>

        <div className="field">
          <label htmlFor="profile-email">Email</label>
          <input
            id="profile-email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </div>

        <div className="field">
          <label htmlFor="profile-bio">Bio</label>
          <textarea id="profile-bio" value={bio} onChange={(event) => setBio(event.target.value)} />
        </div>

        <div className="modal-footer">
          <button type="submit" className="btn btn-primary" disabled={isSavingProfile || !isProfileValid}>
            {isSavingProfile ? 'Saving…' : 'Save Profile'}
          </button>
        </div>
      </form>

      <div className="menu-divider" />

      <form onSubmit={handleChangePassword}>
        <h3>Change Password</h3>
        {passwordError && <p className="error-text">{passwordError}</p>}
        {passwordSuccess && <p className="success-text">{passwordSuccess}</p>}

        <div className="field">
          <label htmlFor="profile-current-password">Current Password</label>
          <input
            id="profile-current-password"
            type="password"
            value={currentPassword}
            onChange={(event) => setCurrentPassword(event.target.value)}
            required
          />
        </div>
        <div className="field">
          <label htmlFor="profile-new-password">New Password</label>
          <input
            id="profile-new-password"
            type="password"
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
            required
          />
        </div>
        <div className="field">
          <label htmlFor="profile-confirm-password">Confirm New Password</label>
          <input
            id="profile-confirm-password"
            type="password"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
            required
          />
        </div>

        <div className="modal-footer">
          <button
            type="submit"
            className="btn"
            disabled={isChangingPassword || !currentPassword || !newPassword || newPassword !== confirmPassword}
          >
            {isChangingPassword ? 'Updating…' : 'Update Password'}
          </button>
        </div>
      </form>

      <div className="menu-divider" />

      <div>
        <h3>Delete Account</h3>
        <p className="menu-note">
          Permanently deletes your account and everything in it — wish lists, items, and any lists shared with a
          partner. This can't be undone.
        </p>
        {deleteError && <p className="error-text">{deleteError}</p>}
        <div className="modal-footer">
          <button type="button" className="btn btn-danger" onClick={() => void handleDeleteAccount()} disabled={isDeleting}>
            {isDeleting ? 'Deleting…' : 'Delete Account'}
          </button>
        </div>
      </div>
    </Modal>
  )
}
