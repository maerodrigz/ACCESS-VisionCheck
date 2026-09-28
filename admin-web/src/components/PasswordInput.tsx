import { useState } from 'react'

import { Eye, EyeOff } from 'lucide-react'



interface PasswordInputProps {

  id?: string

  value: string

  onChange: (value: string) => void

  autoComplete?: string

  placeholder?: string

  className?: string

  disabled?: boolean

}



export function PasswordInput({

  id,

  value,

  onChange,

  autoComplete = 'current-password',

  placeholder,

  className = '',

  disabled = false,

}: PasswordInputProps) {

  const [visible, setVisible] = useState(false)



  return (

    <div className={`relative ${className}`}>

      <input

        id={id}

        type={visible ? 'text' : 'password'}

        autoComplete={autoComplete}

        value={value}

        onChange={(e) => onChange(e.target.value)}

        placeholder={placeholder}

        disabled={disabled}

        className="admin-input w-full rounded-xl py-3 pl-4 pr-11 text-sm disabled:opacity-60"

      />

      <button

        type="button"

        onClick={() => setVisible((v) => !v)}

        disabled={disabled}

        className="absolute right-2 top-1/2 -translate-y-1/2 rounded-lg p-1.5 text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-hover)] disabled:opacity-50"

        aria-label={visible ? 'Hide password' : 'Show password'}

        tabIndex={-1}

      >

        {visible ? <EyeOff size={18} strokeWidth={2} /> : <Eye size={18} strokeWidth={2} />}

      </button>

    </div>

  )

}


