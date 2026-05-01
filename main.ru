expense_tracker/
├── expense.py        # Модель данных (Expense)
├── manager.py        # Хранилище (List + очередь/стек)
├── storage.py        # Работа с JSON
├── view.py           # Консольный ввод/вывод
├── main.py           # Точка входа
├── expenses.json     # Файл с данными (создаётся автоматически)
├── .gitignore
└── README.md
from datetime import datetime


class Expense:
    """Модель расхода с инкапсуляцией"""

    def __init__(self, amount, category, date_str=None):
        self._amount = float(amount)
        self._category = category.strip()
        if date_str:
            self._date = datetime.strptime(date_str, "%Y-%m-%d").date()
        else:
            self._date = datetime.now().date()

    # Геттеры
    def get_amount(self):
        return self._amount

    def get_category(self):
        return self._category

    def get_date(self):
        return self._date

    # Сеттеры с валидацией
    def set_amount(self, amount):
        if amount < 0:
            raise ValueError("Сумма не может быть отрицательной")
        self._amount = amount

    def set_category(self, category):
        if not category.strip():
            raise ValueError("Категория не может быть пустой")
        self._category = category.strip()

    def to_dict(self):
        return {
            "amount": self._amount,
            "category": self._category,
            "date": self._date.strftime("%Y-%m-%d")
        }

    @classmethod
    def from_dict(cls, data):
        return cls(data["amount"], data["category"], data["date"])

    def __str__(self):
        return f"{self._date} | {self._category} | {self._amount:.2f} ₽"
from collections import deque


class ExpenseManager:
    """Управление расходами с использованием List, очереди и стека"""

    def __init__(self):
        self._expenses = []          # основной список расходов
        self._stack = []             # стек для отмены последнего действия
        self._queue = deque()        # очередь для обработки по дате

    def add_expense(self, expense):
        """Добавление расхода"""
        self._stack.append(("add", expense))  # сохраняем для отмены
        self._expenses.append(expense)
        self._rebuild_queue()

    def remove_expense(self, index):
        """Удаление расхода по индексу"""
        if 0 <= index < len(self._expenses):
            removed = self._expenses.pop(index)
            self._stack.append(("remove", removed))
            self._rebuild_queue()
            return removed
        return None

    def undo(self):
        """Отмена последнего действия (стек)"""
        if not self._stack:
            return None
        action, data = self._stack.pop()
        if action == "add":
            # удаляем последний добавленный расход
            self._expenses.pop()
        elif action == "remove":
            # восстанавливаем удалённый расход
            self._expenses.append(data)
        self._rebuild_queue()
        return action

    def _rebuild_queue(self):
        """Перестроить очередь по дате (от старых к новым)"""
        self._queue = deque(sorted(self._expenses, key=lambda e: e.get_date()))

    def get_all(self):
        return self._expenses.copy()

    def get_queue(self):
        return list(self._queue)

    def filter_by_category(self, category):
        return [e for e in self._expenses if e.get_category().lower() == category.lower()]

    def filter_by_date(self, date_str):
        from datetime import datetime
        target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        return [e for e in self._expenses if e.get_date() == target_date]

    def filter_by_date_range(self, start_date_str, end_date_str):
        from datetime import datetime
        start = datetime.strptime(start_date_str, "%Y-%m-%d").date()
        end = datetime.strptime(end_date_str, "%Y-%m-%d").date()
        return [e for e in self._expenses if start <= e.get_date() <= end]

    def get_total_for_period(self, start_date_str, end_date_str):
        filtered = self.filter_by_date_range(start_date_str, end_date_str)
        return sum(e.get_amount() for e in filtered)

    def clear(self):
        self._expenses.clear()
        self._stack.clear()
        self._queue.clear()
import json
from expense import Expense


class Storage:
    """Сериализация/десериализация в JSON"""

    @staticmethod
    def save(expenses, filename="expenses.json"):
        with open(filename, "w", encoding="utf-8") as f:
            json.dump([e.to_dict() for e in expenses], f, ensure_ascii=False, indent=4)

    @staticmethod
    def load(filename="expenses.json"):
        try:
            with open(filename, "r", encoding="utf-8") as f:
                data = json.load(f)
                return [Expense.from_dict(item) for item in data]
        except (FileNotFoundError, json.JSONDecodeError):
            return []
from datetime import datetime


class ConsoleView:
    """Отвечает за вывод меню и ввод данных с валидацией"""

    @staticmethod
    def show_menu():
        print("\n" + "=" * 50)
        print("💰 Expense Tracker — Учёт расходов")
        print("1. Добавить расход")
        print("2. Показать все расходы")
        print("3. Удалить расход")
        print("4. Отменить последнее действие")
        print("5. Показать очередь расходов (по дате)")
        print("6. Фильтр по категории")
        print("7. Фильтр по дате")
        print("8. Фильтр по диапазону дат")
        print("9. Сумма расходов за период")
        print("0. Выход")
        print("=" * 50)

    @staticmethod
    def get_amount():
        """Ввод суммы с валидацией (не отрицательная)"""
        while True:
            try:
                amount = float(input("Сумма: "))
                if amount < 0:
                    print("❌ Ошибка: сумма не может быть отрицательной!")
                    continue
                if amount == 0:
                    print("⚠️ Предупреждение: сумма равна 0")
                return amount
            except ValueError:
                print("❌ Ошибка: введите число!")

    @staticmethod
    def get_category():
        """Ввод категории (не пустая)"""
        while True:
            category = input("Категория (например: Еда, Транспорт, Развлечения): ").strip()
            if category:
                return category
            print("❌ Ошибка: категория не может быть пустой!")

    @staticmethod
    def get_date(prompt="Дата (ГГГГ-ММ-ДД): "):
        """Ввод даты с валидацией формата"""
        while True:
            date_str = input(prompt).strip()
            if not date_str:
                return None
            try:
                datetime.strptime(date_str, "%Y-%m-%d")
                return date_str
            except ValueError:
                print("❌ Ошибка: неверный формат даты! Используйте ГГГГ-ММ-ДД (например: 2024-12-25)")

    @staticmethod
    def show_expenses(expenses, title="Расходы"):
        print(f"\n--- {title} ---")
        if not expenses:
            print("Нет записей.")
            return
        for i, e in enumerate(expenses):
            print(f"{i}. {e}")
        print(f"Всего: {len(expenses)} записей")

    @staticmethod
    def get_index(max_idx):
        while True:
            try:
                idx = int(input(f"Введите индекс (0-{max_idx-1}): "))
                if 0 <= idx < max_idx:
                    return idx
                print(f"❌ Индекс должен быть от 0 до {max_idx-1}")
            except ValueError:
                print("❌ Введите число!")

    @staticmethod
    def get_date_range():
        start = ConsoleView.get_date("Начальная дата (ГГГГ-ММ-ДД): ")
        end = ConsoleView.get_date("Конечная дата (ГГГГ-ММ-ДД): ")
        return start, end

    @staticmethod
    def show_total(amount):
        print(f"\n💰 Сумма расходов: {amount:.2f} ₽")

    @staticmethod
    def show_message(msg):
        print(f"\n✅ {msg}")

    @staticmethod
    def show_error(msg):
        print(f"\n❌ {msg}")
from expense import Expense
from manager import ExpenseManager
from storage import Storage
from view import ConsoleView


class ExpenseTrackerController:
    def __init__(self):
        self.manager = ExpenseManager()
        self.view = ConsoleView()
        self.load_data()

    def load_data(self):
        expenses = Storage.load()
        for e in expenses:
            self.manager.add_expense(e)
        self.view.show_message(f"Загружено {len(expenses)} записей")

    def save_data(self):
        Storage.save(self.manager.get_all())

    def run(self):
        while True:
            self.view.show_menu()
            choice = self.view.get_input = lambda p: input(p).strip()

            choice = input("Выберите действие: ").strip()

            if choice == "1":
                self._add_expense()
            elif choice == "2":
                self._show_all()
            elif choice == "3":
                self._delete_expense()
            elif choice == "4":
                self._undo()
            elif choice == "5":
                self._show_queue()
            elif choice == "6":
                self._filter_by_category()
            elif choice == "7":
                self._filter_by_date()
            elif choice == "8":
                self._filter_by_date_range()
            elif choice == "9":
                self._show_total_for_period()
            elif choice == "0":
                self.save_data()
                self.view.show_message("Данные сохранены. До свидания!")
                break
            else:
                self.view.show_error("Неверный пункт меню")

    def _add_expense(self):
        amount = self.view.get_amount()
        category = self.view.get_category()
        date_str = self.view.get_date()
        expense = Expense(amount, category, date_str)
        self.manager.add_expense(expense)
        self.view.show_message("Расход добавлен")

    def _show_all(self):
        expenses = self.manager.get_all()
        self.view.show_expenses(expenses)

    def _delete_expense(self):
        expenses = self.manager.get_all()
        if not expenses:
            self.view.show_error("Нет записей для удаления")
            return
        self.view.show_expenses(expenses, "Выберите запись для удаления")
        idx = self.view.get_index(len(expenses))
        removed = self.manager.remove_expense(idx)
        if removed:
            self.view.show_message(f"Удалено: {removed}")

    def _undo(self):
        result = self.manager.undo()
        if result:
            self.view.show_message(f"Отменено действие: {'добавление' if result == 'add' else 'удаление'}")
        else:
            self.view.show_error("Нет действий для отмены")

    def _show_queue(self):
        queue = self.manager.get_queue()
        self.view.show_expenses(queue, "Очередь расходов (по дате, от старых к новым)")

    def _filter_by_category(self):
        category = self.view.get_category()
        filtered = self.manager.filter_by_category(category)
        self.view.show_expenses(filtered, f"Расходы по категории '{category}'")

    def _filter_by_date(self):
        date_str = self.view.get_date()
        if not date_str:
            return
        filtered = self.manager.filter_by_date(date_str)
        self.view.show_expenses(filtered, f"Расходы за {date_str}")

    def _filter_by_date_range(self):
        start, end = self.view.get_date_range()
        if not start or not end:
            return
        filtered = self.manager.filter_by_date_range(start, end)
        self.view.show_expenses(filtered, f"Расходы с {start} по {end}")

    def _show_total_for_period(self):
        start, end = self.view.get_date_range()
        if not start or not end:
            return
        total = self.manager.get_total_for_period(start, end)
        self.view.show_total(total)


if __name__ == "__main__":
    app = ExpenseTrackerController()
    app.run()
