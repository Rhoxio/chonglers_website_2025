import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initializeSmoothScrolling()
    this.initializeScrollEffects()
    this.initializeAnimations()
  }

  initializeSmoothScrolling() {
    // Smooth scrolling for navigation links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        e.preventDefault()
        const target = document.querySelector(this.getAttribute('href'))
        if (target) {
          target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          })
        }
      })
    })
  }

  initializeScrollEffects() {
    // Add scroll effect to navigation
    window.addEventListener('scroll', () => {
      const nav = document.querySelector('nav')
      if (window.scrollY > 100) {
        nav.style.background = 'rgba(15, 20, 25, 0.98)'
      } else {
        nav.style.background = 'rgba(15, 20, 25, 0.95)'
      }
    })
  }

  initializeAnimations() {
    // Intersection Observer for animations
    const observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1'
          entry.target.style.transform = 'translateY(0)'
        }
      })
    }, observerOptions)

    // Observe elements for animation
    const animatedElements = document.querySelectorAll('.gallery-item, .feature-card, .stat-item')
    animatedElements.forEach(el => {
      el.style.opacity = '0'
      el.style.transform = 'translateY(30px)'
      el.style.transition = 'opacity 0.6s ease, transform 0.6s ease'
      observer.observe(el)
    })
  }
}