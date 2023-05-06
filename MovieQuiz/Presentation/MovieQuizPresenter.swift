//
//  MovieQuizPresenter.swift
//  MovieQuiz
//
//  Created by Вадим Шишков on 06.05.2023.
//

import UIKit

final class MovieQuizPresenter {
    
    private weak var viewController: MovieQuizViewController?
    private var questionFactory: QuestionFactoryProtocol?
    private var alertPresenter: AlertPresenterProtocol?
    private var statisticService: StatisticService?
    private var currentQuestion: QuizQuestion?
    private let questionsAmount: Int = 10
    private var currentQuestionIndex = 0
    private var correctAnswers = 0
    
    init(viewController: MovieQuizViewController) {
        self.viewController = viewController
        
        alertPresenter = AlertPresenter()
        statisticService = StatisticServiceImplementation()
        questionFactory = QuestionFactory(moviesLoader: MoviesLoader(), delegate: self)
        questionFactory?.loadData()
        
        viewController.showActivityIndicator()
    }
    
    private func convert(model: QuizQuestion) -> QuizStepViewModel {
        let questionStep = QuizStepViewModel(
            image: UIImage(data: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)"
        )
        return questionStep
    }
    
    private func restartGame() {
        currentQuestionIndex = 0
        correctAnswers = 0
        questionFactory?.requestNextQuestion()
    }
    
    private func isLastQuestion() -> Bool {
        currentQuestionIndex == questionsAmount - 1
    }
    
    private func switchToNextQuestion() {
        currentQuestionIndex += 1
    }
    
    private func answerGived(_ givenAnswer: Bool) {
        guard let currentQuestion = currentQuestion else { return }
        proceedWithAnswer(isCorrect: currentQuestion.correctAnswer == givenAnswer)
    }
    
    private func proceedWithAnswer(isCorrect: Bool) {
        viewController?.disableUserInteraction()
        viewController?.highlightImageBorder(isCorrect: isCorrect)
        
        let feedbackGenertor = UINotificationFeedbackGenerator()
        
        if isCorrect {
            feedbackGenertor.notificationOccurred(.success)
            correctAnswers += 1
        } else {
            feedbackGenertor.notificationOccurred(.error)
        }
    
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            proceedToNextQuestionOrResults()
            self.viewController?.enableUserInteraction()
        }
    }
    
    private func showResult() {
        guard let statistic = statisticService,
              let viewController = viewController else { return }
        
        statistic.store(correct: correctAnswers, total: questionsAmount)
        
        let resultModel = AlertModel(
            title: "Этот раунд окончен!",
            message: """
                        Ваш результат: \(correctAnswers)/\(questionsAmount)
                        Количество сыгранных квизов: \(statistic.gamesCount)
                        Рекорд: \(statistic.bestGame.correct)/\(statistic.bestGame.total) (\(statistic.bestGame.date.dateTimeString))
                        Cредняя точность: \(String(format: "%.2f", statistic.totalAccuracy))%
                     """,
            buttonText: "Сыграть еще раз",
            completion: { [weak self] in
                guard let self = self else { return }
                restartGame()
            }
        )
        alertPresenter?.showAlert(quiz: resultModel, on: viewController)
    }
    
    private func showNetworkError(message: String) {
        guard let viewController = viewController else { return }
        
        viewController.hideActivityIndicator()
        
        let alert = AlertModel(
            title: "Ошибка",
            message: message,
            buttonText: "Попробовать еще раз",
            completion: { [weak self] in
                guard let self = self else { return }
                restartGame()
            }
        )
        alertPresenter?.showAlert(quiz: alert, on: viewController)
    }
    
    func yesButtonPressed() {
        answerGived(true)
    }
    
    func noButtonPressed() {
        answerGived(false)
    }
    
    func proceedToNextQuestionOrResults() {
        if isLastQuestion() {
            showResult()
        } else {
            switchToNextQuestion()
            questionFactory?.requestNextQuestion()
        }
    }
}

extension MovieQuizPresenter: QuestionFactoryDelegate {
    
    func didLoadDataFromServer() {
        viewController?.hideActivityIndicator()
        questionFactory?.requestNextQuestion()
    }
    
    func didFailToLoadData(with error: Error) {
        showNetworkError(message: error.localizedDescription)
    }
    
    func didRecieveErrorMessage(_ message: String) {
        guard let viewController = viewController else { return }
        
        let alert = AlertModel(
            title: "Ошибка",
            message: message,
            buttonText: "Попробовать еще раз",
            completion: { [weak self] in
                guard let self = self else { return }
                viewController.showActivityIndicator()
                self.questionFactory?.loadData()
            }
        )
        alertPresenter?.showAlert(quiz: alert, on: viewController)
    }
    
    func didRecieveNextQuestion(question: QuizQuestion?) {
        guard let question = question else { return }
        currentQuestion = question
        let viewModel = convert(model: question)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.viewController?.clearImageBorder()
            self.viewController?.show(quiz: viewModel)
        }
    }
}
