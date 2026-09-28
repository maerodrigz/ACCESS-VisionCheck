import { Quote } from 'lucide-react'
import { AdminCard } from '../AdminCard'
import type { FeaturedTestimonial } from '../../lib/requesterFeedback'
import { organizationInitials } from '../../lib/requesterFeedback'
import { StarRatingDisplay } from './FeedbackBadges'

export function FeaturedTestimonialCard({ testimonial }: { testimonial: FeaturedTestimonial }) {
  return (
    <AdminCard padding="md" className="border-[var(--color-accent-blue)]/20 bg-gradient-to-br from-[var(--color-accent-blue)]/10 to-[var(--color-surface)]">
      <div className="flex items-center gap-2">
        <Quote size={20} className="text-[var(--color-accent-cyan)]" />
        <span className="text-sm font-extrabold text-[var(--color-accent-cyan)]">Featured feedback</span>
        <div className="ml-auto">
          <StarRatingDisplay rating={testimonial.rating} size={16} />
        </div>
      </div>
      <p className="mt-3 text-[15px] italic leading-relaxed text-[var(--color-text-primary)]">
        &ldquo;{testimonial.quote}&rdquo;
      </p>
      <div className="mt-3 flex items-center gap-2">
        <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--color-accent-blue)]/15 text-xs font-extrabold text-[var(--color-accent-blue)]">
          {organizationInitials(testimonial.organization)}
        </div>
        <div>
          <div className="text-sm font-bold text-[var(--color-text-primary)]">{testimonial.organization}</div>
          <div className="text-xs text-[var(--color-text-secondary)]">{testimonial.eventName}</div>
        </div>
      </div>
    </AdminCard>
  )
}
