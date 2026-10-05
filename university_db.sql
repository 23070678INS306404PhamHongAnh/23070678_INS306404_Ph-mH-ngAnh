
--- 0. DATABASE 
DROP DATABASE IF EXISTS university_db;
CREATE DATABASE university_db
    CHARACTER SET utf8mb4          -- utf8mb4 so Vietnamese names display correctly
    COLLATE utf8mb4_unicode_ci;
USE university_db;

-- Drop tables in reverse dependency order (children first)
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS instructors;
DROP TABLE IF EXISTS semesters;
DROP TABLE IF EXISTS departments;

-- 1. DEPARTMENTS: academic departments 
CREATE TABLE departments (
    id          INT AUTO_INCREMENT PRIMARY KEY,          -- surrogate primary key
    code        VARCHAR(10)  NOT NULL UNIQUE,            -- short code, e.g. CS; must be unique
    name        VARCHAR(100) NOT NULL UNIQUE,            -- full department name; must be unique
    description TEXT NULL,                               -- optional long description
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP  -- audit: when the row was created
) ENGINE=InnoDB;

-- 2. SEMESTERS: academic terms (no foreign keys)
CREATE TABLE semesters (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(30) NOT NULL UNIQUE,                -- e.g. 'Fall 2024'
    academic_year VARCHAR(9)  NOT NULL,                       -- e.g. '2024-2025'
    term          ENUM('Fall','Spring','Summer') NOT NULL,    -- fixed set of terms
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    CONSTRAINT uq_semester_year_term UNIQUE (academic_year, term),  -- one term per year
    CONSTRAINT chk_semester_dates CHECK (end_date > start_date)     -- end must be after start
) ENGINE=InnoDB;

-- 3. INSTRUCTORS: each instructor belongs to one department (1:N)
CREATE TABLE instructors (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    instructor_code VARCHAR(10)  NOT NULL UNIQUE,             -- e.g. GV001
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,             -- unique login/contact email
    phone           VARCHAR(15)  NULL,
    gender          ENUM('male','female','other') NOT NULL DEFAULT 'other',
    hire_date       DATE NOT NULL,
    department_id   INT NOT NULL,                             -- FK to departments
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- RESTRICT: cannot delete a department that still has instructors
    -- CASCADE : if department id changes, update it here too
    CONSTRAINT fk_instructors_department FOREIGN KEY (department_id)
        REFERENCES departments(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 4. STUDENTS: each student has one major department (1:N)
CREATE TABLE students (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    student_code  VARCHAR(12)  NOT NULL UNIQUE,               -- e.g. SV2021001
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    gender        ENUM('male','female','other') NOT NULL DEFAULT 'other',
    date_of_birth DATE NOT NULL,
    admission_date DATE NOT NULL,                             -- date the student was admitted
    gpa           DECIMAL(3,2) NOT NULL DEFAULT 0.00,         -- 4.0 scale, 2 decimals (e.g. 3.45)
    status        ENUM('active','on_leave','graduated','dropped') NOT NULL DEFAULT 'active',
    department_id INT NOT NULL,                               -- FK: the student's major
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_students_gpa CHECK (gpa BETWEEN 0.00 AND 4.00),
    CONSTRAINT fk_students_department FOREIGN KEY (department_id)
        REFERENCES departments(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 5. COURSES: belongs to a department, taught by one instructor
CREATE TABLE courses (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    course_code   VARCHAR(10)  NOT NULL UNIQUE,               -- e.g. CS101
    title         VARCHAR(150) NOT NULL,
    description   TEXT NULL,                                  -- long course description
    credits       TINYINT NOT NULL DEFAULT 3,                 -- most courses are 3 credits
    department_id INT NOT NULL,                               -- FK: offering department
    instructor_id INT NULL,                                   -- FK: may be NULL if unassigned
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_courses_credits CHECK (credits BETWEEN 1 AND 6),
    CONSTRAINT fk_courses_department FOREIGN KEY (department_id)
        REFERENCES departments(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- SET NULL: deleting an instructor keeps the course but leaves it unassigned
    CONSTRAINT fk_courses_instructor FOREIGN KEY (instructor_id)
        REFERENCES instructors(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 6. ENROLLMENTS: junction table for the M:N relationship
--    between students and courses, per semester
CREATE TABLE enrollments (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    student_id   INT NOT NULL,
    course_id    INT NOT NULL,
    semester_id  INT NOT NULL,
    enrolled_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status       ENUM('enrolled','completed','withdrawn') NOT NULL DEFAULT 'enrolled',
    grade        DECIMAL(3,2) NULL,                           -- 4.0 scale; NULL until graded
    grade_letter ENUM('A','B+','B','C+','C','D+','D','F') NULL, -- NULL until graded
    -- A student cannot register for the same course twice in the same semester
    CONSTRAINT uq_enrollment UNIQUE (student_id, course_id, semester_id),
    CONSTRAINT chk_enrollments_grade CHECK (grade IS NULL OR grade BETWEEN 0.00 AND 4.00),
    -- CASCADE: deleting a student/course/semester removes its enrollment rows
    CONSTRAINT fk_enrollments_student FOREIGN KEY (student_id)
        REFERENCES students(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_enrollments_course FOREIGN KEY (course_id)
        REFERENCES courses(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_enrollments_semester FOREIGN KEY (semester_id)
        REFERENCES semesters(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- SAMPLE DATA (inserted in dependency order)

-- Departments (5)
INSERT INTO departments (code, name, description) VALUES
('CS',   'Computer Science',            'Programming, algorithms, software engineering and artificial intelligence.'),
('IS',   'Information Systems',         'Databases, systems analysis and enterprise information systems.'),
('ECE',  'Electronics and Telecommunications', 'Digital circuits, embedded systems and communication networks.'),
('MATH', 'Mathematics',                 'Pure and applied mathematics, statistics and probability.'),
('BA',   'Business Administration',     'Management, marketing, finance and entrepreneurship.');

-- Semesters (5)
INSERT INTO semesters (name, academic_year, term, start_date, end_date) VALUES
('Fall 2023',   '2023-2024', 'Fall',   '2023-09-05', '2024-01-12'),
('Spring 2024', '2023-2024', 'Spring', '2024-02-05', '2024-06-14'),
('Summer 2024', '2023-2024', 'Summer', '2024-06-24', '2024-08-16'),
('Fall 2024',   '2024-2025', 'Fall',   '2024-09-04', '2025-01-10'),
('Spring 2025', '2024-2025', 'Spring', '2025-02-03', '2025-06-13');

-- Instructors (7)
INSERT INTO instructors (instructor_code, full_name, email, phone, gender, hire_date, department_id) VALUES
('GV001', 'Nguyễn Văn Hùng',  'hung.nguyen@university.edu.vn', '0912345001', 'male',   '2015-08-20', 1),
('GV002', 'Trần Thị Lan',     'lan.tran@university.edu.vn',    '0912345002', 'female', '2017-03-15', 1),
('GV003', 'Lê Minh Tuấn',     'tuan.le@university.edu.vn',     '0912345003', 'male',   '2012-09-01', 2),
('GV004', 'Phạm Thu Hà',      'ha.pham@university.edu.vn',     '0912345004', 'female', '2019-01-10', 2),
('GV005', 'Hoàng Đức Thắng',  'thang.hoang@university.edu.vn', '0912345005', 'male',   '2014-06-25', 3),
('GV006', 'Vũ Thị Mai',       'mai.vu@university.edu.vn',      '0912345006', 'female', '2016-11-05', 4),
('GV007', 'Đặng Quốc Bảo',    'bao.dang@university.edu.vn',    '0912345007', 'male',   '2018-02-12', 5);

-- Students (10); gpa is recalculated from enrollments at the end of the script
INSERT INTO students (student_code, full_name, email, gender, date_of_birth, admission_date, status, department_id) VALUES
('SV2021001', 'Nguyễn Minh Anh',    'anh.nm@student.edu.vn',    'female', '2003-04-12', '2021-09-01', 'active',    1),
('SV2021002', 'Trần Quang Huy',     'huy.tq@student.edu.vn',    'male',   '2003-07-23', '2021-09-01', 'active',    1),
('SV2021003', 'Lê Thị Thu Trang',   'trang.ltt@student.edu.vn', 'female', '2003-01-30', '2021-09-01', 'active',    2),
('SV2022004', 'Phạm Đức Anh',       'anh.pd@student.edu.vn',    'male',   '2004-05-17', '2022-09-01', 'active',    1),
('SV2022005', 'Hoàng Thị Lan Anh',  'lananh.ht@student.edu.vn', 'female', '2004-09-08', '2022-09-01', 'active',    2),
('SV2022006', 'Vũ Hải Nam',         'nam.vh@student.edu.vn',    'male',   '2004-11-02', '2022-09-01', 'active',    3),
('SV2022007', 'Đặng Thu Phương',    'phuong.dt@student.edu.vn', 'female', '2004-02-19', '2022-09-01', 'active',    4),
('SV2023008', 'Bùi Văn Khánh',      'khanh.bv@student.edu.vn',  'male',   '2005-06-14', '2023-09-01', 'active',    5),
('SV2023009', 'Ngô Thị Bích Ngọc',  'ngoc.ntb@student.edu.vn',  'female', '2005-03-27', '2023-09-01', 'on_leave',  5),
('SV2023010', 'Đỗ Tiến Dũng',       'dung.dt@student.edu.vn',   'male',   '2005-08-05', '2023-09-01', 'active',    1);

-- Courses (8)
INSERT INTO courses (course_code, title, description, credits, department_id, instructor_id) VALUES
('CS101',   'Introduction to Programming',        'Basic programming concepts using Python: variables, control flow, functions.', 3, 1, 1),
('CS201',   'Data Structures and Algorithms',     'Arrays, linked lists, trees, graphs, sorting and complexity analysis.',        4, 1, 2),
('CS350',   'Web Development',                    'HTML, CSS, JavaScript and server-side web programming.',                       3, 1, 1),
('IS301',   'Database Systems',                   'Relational model, SQL, normalization and transactions.',                       3, 2, 3),
('IS210',   'Systems Analysis and Design',        'Requirements gathering, UML modeling and system design.',                      3, 2, 4),
('ECE150',  'Digital Logic Design',               'Boolean algebra, logic gates, flip-flops and sequential circuits.',            3, 3, 5),
('MATH101', 'Calculus I',                         'Limits, derivatives and integrals of single-variable functions.',              4, 4, 6),
('BA101',   'Principles of Management',           'Fundamentals of planning, organizing, leading and controlling.',               3, 5, 7);

-- Enrollments (27) - various student/course/semester combinations
-- Semester ids: 1=Fall 2023, 2=Spring 2024, 3=Summer 2024, 4=Fall 2024, 5=Spring 2025
INSERT INTO enrollments (student_id, course_id, semester_id, status, grade, grade_letter) VALUES
-- Student 1 (Nguyễn Minh Anh): strong student
(1, 1, 1, 'completed', 4.00, 'A'),
(1, 7, 1, 'completed', 3.50, 'B+'),
(1, 2, 2, 'completed', 3.50, 'B+'),
(1, 4, 4, 'enrolled',  NULL, NULL),
-- Student 2 (Trần Quang Huy)
(2, 1, 1, 'completed', 3.00, 'B'),
(2, 7, 1, 'completed', 2.50, 'C+'),
(2, 2, 2, 'completed', 3.00, 'B'),
(2, 3, 4, 'enrolled',  NULL, NULL),
-- Student 3 (Lê Thị Thu Trang)
(3, 1, 1, 'completed', 3.50, 'B+'),
(3, 4, 2, 'completed', 4.00, 'A'),
(3, 5, 4, 'enrolled',  NULL, NULL),
-- Student 4 (Phạm Đức Anh)
(4, 1, 2, 'completed', 2.00, 'C'),
(4, 2, 4, 'enrolled',  NULL, NULL),
-- Student 5 (Hoàng Thị Lan Anh)
(5, 4, 2, 'completed', 3.00, 'B'),
(5, 5, 2, 'completed', 3.50, 'B+'),
-- Student 6 (Vũ Hải Nam)
(6, 6, 1, 'completed', 3.00, 'B'),
(6, 7, 2, 'completed', 2.50, 'C+'),
-- Student 7 (Đặng Thu Phương)
(7, 7, 1, 'completed', 4.00, 'A'),
(7, 1, 3, 'completed', 3.50, 'B+'),
-- Student 8 (Bùi Văn Khánh): failed Calculus I, then retook it
(8, 7, 1, 'completed', 0.00, 'F'),
(8, 7, 2, 'completed', 2.00, 'C'),
(8, 8, 2, 'completed', 3.00, 'B'),
-- Student 9 (Ngô Thị Bích Ngọc)
(9, 8, 2, 'completed', 3.50, 'B+'),
(9, 1, 4, 'enrolled',  NULL, NULL),
-- Student 10 (Đỗ Tiến Dũng)
(10, 1, 1, 'completed', 2.50, 'C+'),
(10, 2, 2, 'withdrawn', NULL, NULL),
(10, 3, 5, 'enrolled',  NULL, NULL);

-- Keep students.gpa consistent with enrollments:
-- credit-weighted average of graded courses (0.00 if the student has no grades yet)
UPDATE students s
SET s.gpa = COALESCE((
    SELECT ROUND(SUM(e.grade * c.credits) / SUM(c.credits), 2)
    FROM enrollments e
    JOIN courses c ON c.id = e.course_id
    WHERE e.student_id = s.id AND e.grade IS NOT NULL
), 0.00);
