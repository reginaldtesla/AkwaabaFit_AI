# AkwaabaFitAIProject

## Overview

AkwaabaFitAIProject is a comprehensive fitness application that combines AI-powered workout recommendations with a user-friendly mobile interface. The project consists of a Laravel-based backend API and a Flutter mobile application, designed to provide personalized fitness experiences.

## Project Structure

```
AkwaabaFitAIProject/
├── Backend/          # Laravel API backend
├── Mobile/           # Flutter mobile application
└── README.md         # This file
```

## Features

- **AI-Powered Workouts**: Personalized workout recommendations based on user goals and fitness level
- **Progress Tracking**: Monitor fitness progress over time
- **User Authentication**: Secure user accounts with Laravel Sanctum
- **Cross-Platform Mobile App**: Flutter app that works on iOS and Android
- **RESTful API**: Well-structured backend API for data management

## Technology Stack

### Backend

- **Laravel 12**: PHP framework for robust API development
- **Laravel Sanctum**: API authentication
- **MySQL/PostgreSQL**: Database (configurable)
- **Pest**: PHP testing framework

### Mobile

- **Flutter**: Cross-platform mobile development
- **Dart**: Programming language

## Prerequisites

### Backend Requirements

- PHP 8.2 or higher
- Composer
- Node.js & npm (for asset compilation)
- MySQL/PostgreSQL database

### Mobile Requirements

- Flutter SDK
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

## Installation & Setup

### Backend Setup

1. Navigate to the Backend directory:

   ```bash
   cd Backend
   ```

2. Install PHP dependencies:

   ```bash
   composer install
   ```

3. Install Node.js dependencies:

   ```bash
   npm install
   ```

4. Copy environment file and configure:

   ```bash
   cp .env.example .env
   ```

5. Generate application key:

   ```bash
   php artisan key:generate
   ```

6. Configure your database in `.env` file

7. Run database migrations:

   ```bash
   php artisan migrate
   ```

8. Start the development server:
   ```bash
   php artisan serve
   ```

### Mobile Setup

1. Navigate to the Mobile directory:

   ```bash
   cd Mobile
   ```

2. Install Flutter dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## API Documentation

The backend provides RESTful APIs for:

- User authentication and management
- Workout data management
- Progress tracking
- AI recommendations

API endpoints are defined in `Backend/routes/api.php`

## Testing

### Backend Testing

```bash
cd Backend
php artisan test
```

### Mobile Testing

```bash
cd Mobile
flutter test
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Project Team

This is a final year group project. Team members:

- [Add team member names and roles]

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Laravel Framework
- Flutter Framework
- All contributors and supporters

## Contact

For questions or support, please contact the project maintainers.
