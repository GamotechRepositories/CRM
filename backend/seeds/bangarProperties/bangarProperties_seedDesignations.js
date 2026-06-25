import dotenv from 'dotenv'
import connectDB from '../config/db.js'
import Designation from '../models/designation.js'

dotenv.config()

const designations = [
  'Chief Executive Officer',
  'Chief Technology Officer',
  'Chief Operating Officer',
  'Chief Financial Officer',
  'Head of Product',
  'Product Manager',
  'Project Manager',
  'Program Manager',
  'Engineering Manager',
  'Technical Lead',
  'Software Engineer',
  'Senior Software Engineer',
  'Frontend Engineer',
  'Backend Engineer',
  'Full Stack Engineer',
  'Mobile Developer',
  'DevOps Engineer',
  'Site Reliability Engineer',
  'QA Engineer',
  'Test Engineer',
  'Security Engineer',
  'Database Administrator',
  'System Administrator',
  'UI/UX Designer',
  'Graphic Designer',
  'Motion Designer',
  'Creative Director',
  'Art Director',
  'Copywriter',
  'Content Writer',
  'SEO Specialist',
  'SEM/PPC Specialist',
  'Social Media Manager',
  'Digital Marketing Manager',
  'Growth Marketer',
  'Email Marketing Specialist',
  'Brand Manager',
  'Community Manager',
  'Analytics Manager',
  'Data Analyst',
  'Data Scientist',
  'Business Analyst',
  'Sales Manager',
  'Account Manager',
  'Customer Success Manager',
  'Support Engineer',
  'HR Manager',
  'Recruiter',
  'Office Manager',
  'Intern',
]

const seed = async () => {
  try {
    await connectDB()
    console.log('Seeding designations...')

    for (const title of designations) {
      await Designation.findOneAndUpdate(
        { title },
        { title, description: '' },
        { upsert: true, new: true }
      )
    }

    console.log('Designations seeded successfully')
    process.exit(0)
  } catch (error) {
    console.error('Seeding error:', error)
    process.exit(1)
  }
}

seed()
