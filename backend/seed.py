"""
Run: python seed.py
Adds 15 real-world KZ internships to the database.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))

from app.db import SessionLocal, Base, engine
from app.models import Internship

Base.metadata.create_all(bind=engine)

INTERNSHIPS = [
    {
        "title": "Junior Python Developer",
        "company": "Kaspi Bank",
        "city": "Алматы",
        "format": "Hybrid",
        "paid": True,
        "salary_kzt": 180000,
        "duration": "3 месяца",
        "category": "IT",
        "description": "Присоединяйтесь к команде Kaspi Bank и участвуйте в разработке финансовых сервисов, которыми пользуются миллионы казахстанцев. Вы будете работать с микросервисной архитектурой и современным Python-стеком.",
        "responsibilities": [
            "Разработка REST API на FastAPI/Django",
            "Написание unit и интеграционных тестов",
            "Участие в код-ревью",
            "Работа с PostgreSQL и Redis",
        ],
        "requirements": [
            "Знание Python (основы ООП)",
            "Базовое понимание SQL",
            "Желание учиться и развиваться",
        ],
        "skills": ["Python", "FastAPI", "PostgreSQL", "Git"],
        "tags": ["backend", "python", "fintech"],
        "contact_email": "careers@kaspi.kz",
    },
    {
        "title": "Frontend React Intern",
        "company": "Kaspi Bank",
        "city": "Алматы",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 160000,
        "duration": "3 месяца",
        "category": "IT",
        "description": "Разрабатывайте интерфейсы для одного из крупнейших финтех-приложений Казахстана. Вы будете работать рядом с опытными React-разработчиками и видеть результат своей работы в реальном продукте.",
        "responsibilities": [
            "Верстка UI-компонентов на React",
            "Интеграция с REST API",
            "Оптимизация производительности",
            "Участие в дизайн-ревью",
        ],
        "requirements": [
            "Знание HTML/CSS/JavaScript",
            "Базовые знания React",
            "Понимание принципов адаптивной верстки",
        ],
        "skills": ["React", "TypeScript", "CSS", "Git"],
        "tags": ["frontend", "react", "fintech"],
        "contact_email": "careers@kaspi.kz",
    },
    {
        "title": "Data Analyst Intern",
        "company": "Halyk Bank",
        "city": "Алматы",
        "format": "Hybrid",
        "paid": True,
        "salary_kzt": 150000,
        "duration": "4 месяца",
        "category": "Финансы",
        "description": "Halyk Bank приглашает начинающих аналитиков данных для работы с большими объёмами финансовых данных. Вы получите опыт работы с реальными данными банка и построите первые аналитические дашборды.",
        "responsibilities": [
            "Сбор и очистка данных из различных источников",
            "Построение отчётов и визуализаций в Power BI",
            "Анализ клиентского поведения",
            "Подготовка презентаций для менеджмента",
        ],
        "requirements": [
            "Знание SQL на базовом уровне",
            "Excel (сводные таблицы, формулы)",
            "Желательно: Python pandas",
        ],
        "skills": ["SQL", "Excel", "Power BI", "Python"],
        "tags": ["analytics", "data", "finance"],
        "contact_email": "hr@halykbank.kz",
    },
    {
        "title": "Mobile iOS Developer",
        "company": "Kolesa Group",
        "city": "Алматы",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 200000,
        "duration": "3 месяца",
        "category": "IT",
        "description": "Kolesa.kz — крупнейший автомобильный маркетплейс Казахстана. Войдите в iOS-команду и помогайте миллионам пользователей покупать и продавать автомобили через мобильное приложение.",
        "responsibilities": [
            "Разработка новых фич в Swift",
            "Исправление багов и рефакторинг",
            "Написание unit-тестов",
            "Участие в планировании спринтов",
        ],
        "requirements": [
            "Базовые знания Swift",
            "Понимание UIKit или SwiftUI",
            "Знание основ ООП",
        ],
        "skills": ["Swift", "SwiftUI", "Xcode", "Git"],
        "tags": ["ios", "mobile", "swift"],
        "contact_email": "jobs@kolesa.kz",
    },
    {
        "title": "UX/UI Designer",
        "company": "Kolesa Group",
        "city": "Алматы",
        "format": "Hybrid",
        "paid": True,
        "salary_kzt": 140000,
        "duration": "3 месяца",
        "category": "Дизайн",
        "description": "Проектируйте пользовательские интерфейсы для продуктов с многомиллионной аудиторией. Вы будете работать в тесной связке с продуктовой командой и разработчиками.",
        "responsibilities": [
            "Проектирование wireframes и прототипов",
            "Проведение пользовательских исследований",
            "Создание дизайн-системы компонентов",
            "Подготовка макетов для разработки",
        ],
        "requirements": [
            "Знание Figma",
            "Понимание принципов UX",
            "Портфолио (даже учебные работы)",
        ],
        "skills": ["Figma", "UX Research", "Prototyping"],
        "tags": ["design", "ux", "figma"],
        "contact_email": "jobs@kolesa.kz",
    },
    {
        "title": "Backend Java Developer",
        "company": "Jusan Bank",
        "city": "Астана",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 170000,
        "duration": "3 месяца",
        "category": "IT",
        "description": "Jusan Bank активно развивает цифровые продукты и ищет Junior Java-разработчиков для усиления команды. Работайте над высоконагруженными банковскими сервисами.",
        "responsibilities": [
            "Разработка микросервисов на Spring Boot",
            "Интеграция с внешними API",
            "Написание тестов (JUnit)",
            "Участие в архитектурных обсуждениях",
        ],
        "requirements": [
            "Java Core (Collections, OOP)",
            "Базовые знания Spring",
            "SQL",
        ],
        "skills": ["Java", "Spring Boot", "PostgreSQL", "Docker"],
        "tags": ["backend", "java", "fintech"],
        "contact_email": "careers@jusan.kz",
    },
    {
        "title": "Marketing Intern",
        "company": "Wildberries Казахстан",
        "city": "Алматы",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 120000,
        "duration": "2 месяца",
        "category": "Маркетинг",
        "description": "Присоединяйтесь к маркетинговой команде Wildberries и участвуйте в продвижении одного из крупнейших e-commerce платформ в Казахстане.",
        "responsibilities": [
            "Ведение социальных сетей",
            "Анализ конкурентов",
            "Подготовка контента для акций",
            "Работа с инфлюенсерами",
        ],
        "requirements": [
            "Грамотный русский язык",
            "Базовые знания SMM",
            "Творческое мышление",
        ],
        "skills": ["SMM", "Canva", "Instagram", "Копирайтинг"],
        "tags": ["marketing", "smm", "ecommerce"],
        "contact_email": "hr@wb.kz",
    },
    {
        "title": "DevOps Engineer Intern",
        "company": "EPAM Systems Kazakhstan",
        "city": "Алматы",
        "format": "Remote",
        "paid": True,
        "salary_kzt": 190000,
        "duration": "6 месяцев",
        "category": "IT",
        "description": "EPAM — глобальная IT-компания с офисом в Алматы. Войдите в DevOps-команду и работайте с современным стеком CI/CD инструментов на международных проектах.",
        "responsibilities": [
            "Настройка и поддержка CI/CD пайплайнов",
            "Работа с Kubernetes и Docker",
            "Мониторинг систем (Grafana, Prometheus)",
            "Автоматизация рутинных задач",
        ],
        "requirements": [
            "Основы Linux",
            "Базовые знания Docker",
            "Английский язык (читать документацию)",
        ],
        "skills": ["Docker", "Kubernetes", "CI/CD", "Linux", "AWS"],
        "tags": ["devops", "cloud", "kubernetes"],
        "contact_email": "kazakhstan@epam.com",
    },
    {
        "title": "HR Intern",
        "company": "Beeline Казахстан",
        "city": "Алматы",
        "format": "Hybrid",
        "paid": True,
        "salary_kzt": 110000,
        "duration": "3 месяца",
        "category": "HR",
        "description": "Beeline Kazakhstan ищет HR-стажёра для поддержки команды по подбору персонала. Вы получите полноценный опыт работы в HR крупной телеком-компании.",
        "responsibilities": [
            "Помощь в подборе персонала (скрининг резюме)",
            "Организация и проведение собеседований",
            "Ведение HR-документации",
            "Помощь в адаптации новых сотрудников",
        ],
        "requirements": [
            "Хорошие коммуникативные навыки",
            "Внимательность к деталям",
            "Знание MS Office",
        ],
        "skills": ["Рекрутинг", "HR", "Коммуникации", "MS Office"],
        "tags": ["hr", "recruiting", "telecom"],
        "contact_email": "hr@beeline.kz",
    },
    {
        "title": "Graphic Designer Intern",
        "company": "Chocofamily",
        "city": "Алматы",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 130000,
        "duration": "3 месяца",
        "category": "Дизайн",
        "description": "Chocofamily — экосистема казахстанских сервисов (Chocotravel, Chocofood, Chocolife). Создавайте визуальный контент для брендов, которыми пользуется весь Казахстан.",
        "responsibilities": [
            "Создание баннеров для digital-каналов",
            "Дизайн email-рассылок",
            "Подготовка материалов для социальных сетей",
            "Работа с брендбуком компании",
        ],
        "requirements": [
            "Знание Adobe Photoshop / Illustrator",
            "Чувство стиля и цвета",
            "Портфолио",
        ],
        "skills": ["Photoshop", "Illustrator", "Figma", "Брендинг"],
        "tags": ["design", "graphic", "branding"],
        "contact_email": "jobs@chocofamily.kz",
    },
    {
        "title": "Product Manager Intern",
        "company": "Chocofamily",
        "city": "Алматы",
        "format": "Hybrid",
        "paid": True,
        "salary_kzt": 155000,
        "duration": "4 месяца",
        "category": "IT",
        "description": "Управляйте продуктовыми фичами в одной из ведущих tech-компаний Казахстана. Вы будете работать напрямую с CPO и изучите весь product development цикл.",
        "responsibilities": [
            "Сбор и анализ продуктовых метрик",
            "Написание user stories и технических заданий",
            "Координация между дизайном и разработкой",
            "Проведение A/B тестов",
        ],
        "requirements": [
            "Аналитическое мышление",
            "Базовое понимание Agile/Scrum",
            "Умение работать с данными",
        ],
        "skills": ["Product Management", "Agile", "Analytics", "Jira"],
        "tags": ["product", "management", "agile"],
        "contact_email": "jobs@chocofamily.kz",
    },
    {
        "title": "QA Engineer Intern",
        "company": "Jusan Bank",
        "city": "Астана",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 140000,
        "duration": "3 месяца",
        "category": "IT",
        "description": "Обеспечивайте качество банковских продуктов в Jusan Bank. Вы изучите ручное и автоматизированное тестирование на реальных проектах.",
        "responsibilities": [
            "Написание тест-кейсов и чек-листов",
            "Ручное тестирование мобильных и web-приложений",
            "Составление баг-репортов",
            "Участие в регрессионном тестировании",
        ],
        "requirements": [
            "Понимание жизненного цикла ПО",
            "Внимательность и методичность",
            "Желательно: основы SQL",
        ],
        "skills": ["Manual QA", "Postman", "SQL", "Jira"],
        "tags": ["qa", "testing", "fintech"],
        "contact_email": "careers@jusan.kz",
    },
    {
        "title": "Machine Learning Intern",
        "company": "EPAM Systems Kazakhstan",
        "city": "Алматы",
        "format": "Remote",
        "paid": True,
        "salary_kzt": 220000,
        "duration": "6 месяцев",
        "category": "IT",
        "description": "Работайте над реальными ML-проектами в EPAM для международных клиентов. Применяйте академические знания на практике под руководством Senior ML-инженеров.",
        "responsibilities": [
            "Обработка и анализ датасетов",
            "Обучение и валидация ML-моделей",
            "Написание пайплайнов данных",
            "Подготовка отчётов о результатах экспериментов",
        ],
        "requirements": [
            "Python (numpy, pandas, scikit-learn)",
            "Базовые знания математики (линейная алгебра, статистика)",
            "Английский язык (intermediate+)",
        ],
        "skills": ["Python", "TensorFlow", "scikit-learn", "pandas"],
        "tags": ["ml", "ai", "data science"],
        "contact_email": "kazakhstan@epam.com",
    },
    {
        "title": "Content Marketing Intern",
        "company": "Beeline Казахстан",
        "city": "Алматы",
        "format": "Remote",
        "paid": False,
        "salary_kzt": None,
        "duration": "2 месяца",
        "category": "Маркетинг",
        "description": "Создавайте контент для одного из крупнейших телеком-брендов Казахстана. Отличная возможность собрать портфолио и получить рекомендательное письмо.",
        "responsibilities": [
            "Написание статей для блога и соцсетей",
            "Съёмка и монтаж коротких видео",
            "Взаимодействие с партнёрами по контенту",
        ],
        "requirements": [
            "Грамотный русский и казахский языки",
            "Творческий подход",
            "Базовые навыки монтажа (желательно)",
        ],
        "skills": ["Копирайтинг", "SMM", "CapCut", "Canva"],
        "tags": ["content", "marketing", "telecom"],
        "contact_email": "hr@beeline.kz",
    },
    {
        "title": "Android Developer Intern",
        "company": "Kolesa Group",
        "city": "Алматы",
        "format": "Офис",
        "paid": True,
        "salary_kzt": 190000,
        "duration": "3 месяца",
        "category": "IT",
        "description": "Разрабатывайте Android-приложение Kolesa.kz, которым пользуются более 2 миллионов человек в Казахстане. Работайте с современным Kotlin-стеком.",
        "responsibilities": [
            "Разработка новых экранов на Jetpack Compose",
            "Работа с Retrofit и Room",
            "Написание unit-тестов",
            "Code review с тимлидом",
        ],
        "requirements": [
            "Базовые знания Kotlin",
            "Понимание Android SDK",
            "Знание основ ООП",
        ],
        "skills": ["Kotlin", "Jetpack Compose", "Android", "Git"],
        "tags": ["android", "mobile", "kotlin"],
        "contact_email": "jobs@kolesa.kz",
    },
]


def seed():
    db = SessionLocal()
    try:
        existing = db.query(Internship).count()
        if existing > 0:
            print(f"Already have {existing} internships. Skipping seed.")
            return

        for data in INTERNSHIPS:
            internship = Internship(**data)
            db.add(internship)

        db.commit()
        print(f"✅ Added {len(INTERNSHIPS)} internships successfully!")
    except Exception as e:
        db.rollback()
        print(f"❌ Error: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
