import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "mainImage", "placeholder", "title", "description"]

  connect() {
    // Add keyboard navigation
    document.addEventListener("keydown", this.handleKeydown.bind(this))

    // Auto-select the active thumbnail to show the clicked image
    this.selectActiveThumbnail()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.remove()
    }
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (!this.hasModalTarget) return

    switch(event.key) {
      case "Escape":
        this.close()
        break
      case "ArrowLeft":
        event.preventDefault()
        this.previousImage()
        break
      case "ArrowRight":
        event.preventDefault()
        this.nextImage()
        break
    }
  }

  previousImage() {
    const currentActive = this.element.querySelector('.carousel-thumb.active')
    if (!currentActive) return

    const thumbnails = Array.from(this.element.querySelectorAll('.carousel-thumb'))
    const currentIndex = thumbnails.indexOf(currentActive)
    const previousIndex = currentIndex > 0 ? currentIndex - 1 : thumbnails.length - 1

    this.selectThumbnailByIndex(previousIndex)
  }

  nextImage() {
    const currentActive = this.element.querySelector('.carousel-thumb.active')
    if (!currentActive) return

    const thumbnails = Array.from(this.element.querySelectorAll('.carousel-thumb'))
    const currentIndex = thumbnails.indexOf(currentActive)
    const nextIndex = currentIndex < thumbnails.length - 1 ? currentIndex + 1 : 0

    this.selectThumbnailByIndex(nextIndex)
  }

  selectThumbnailByIndex(index) {
    const thumbnails = this.element.querySelectorAll('.carousel-thumb')
    if (thumbnails[index]) {
      // Remove active class from all thumbnails
      thumbnails.forEach(thumb => thumb.classList.remove('active'))

      // Add active class to selected thumbnail
      thumbnails[index].classList.add('active')

      // Update main image
      this.updateMainImage(thumbnails[index])
    }
  }

  selectThumbnail(event) {
    const thumbnail = event.currentTarget

    // Remove active class from all thumbnails
    this.element.querySelectorAll('.carousel-thumb').forEach(thumb => {
      thumb.classList.remove('active')
    })

    // Add active class to selected thumbnail
    thumbnail.classList.add('active')

    // Update main image
    this.updateMainImage(thumbnail)
  }

  selectActiveThumbnail() {
    // Find the thumbnail that's already marked as active and load its image
    const activeThumbnail = this.element.querySelector('.carousel-thumb.active')
    if (activeThumbnail) {
      this.updateMainImage(activeThumbnail)
    }
  }

  updateMainImage(thumbnail) {
    const fullUrl = thumbnail.dataset.thumbnailFullUrlValue
    const title = thumbnail.dataset.thumbnailTitleValue
    const description = thumbnail.dataset.thumbnailDescriptionValue

    if (this.hasMainImageTarget && fullUrl) {
      // Hide placeholder
      if (this.hasPlaceholderTarget) {
        this.placeholderTarget.style.display = 'none'
      }

      // Load the full image
      this.mainImageTarget.src = fullUrl
      this.mainImageTarget.alt = title || ''
      this.mainImageTarget.style.display = 'block'

      // Update info
      if (this.hasTitleTarget) {
        this.titleTarget.textContent = title || ''
      }

      if (this.hasDescriptionTarget) {
        this.descriptionTarget.textContent = description || ''
      }
    }
  }
}