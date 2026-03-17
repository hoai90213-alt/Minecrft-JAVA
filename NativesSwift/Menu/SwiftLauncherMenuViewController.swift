import UIKit

final class SwiftLauncherMenuViewController: UIViewController {
    var items: [DashboardMenuItem] = .defaults {
        didSet { applySnapshot() }
    }

    var onSelectItem: ((DashboardMenuItem) -> Void)?

    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        view.applyGlassCard(cornerRadius: GlassTheme.cardRadius)
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: buildLayout())
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = false
        collection.keyboardDismissMode = .onDrag
        collection.register(MenuIconCell.self, forCellWithReuseIdentifier: MenuIconCell.reuseID)
        collection.delegate = self
        return collection
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Int, DashboardMenuItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = GlassTheme.background
        buildHierarchy()
        configureDataSource()
        applySnapshot()
    }

    private func buildHierarchy() {
        view.addSubview(blurView)
        blurView.contentView.addSubview(collectionView)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            blurView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            blurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            blurView.widthAnchor.constraint(equalToConstant: 72),

            collectionView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 8),
            collectionView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -8),
            collectionView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 8),
            collectionView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -8)
        ])
    }

    private func buildLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(GlassTheme.itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(400)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitem: item, count: 1)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, DashboardMenuItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, model in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: MenuIconCell.reuseID,
                for: indexPath
            ) as? MenuIconCell else {
                return UICollectionViewCell()
            }
            cell.render(item: model)
            return cell
        }
    }

    private func applySnapshot() {
        guard isViewLoaded else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Int, DashboardMenuItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(items, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension SwiftLauncherMenuViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selected = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelectItem?(selected)
    }
}

private final class MenuIconCell: UICollectionViewCell {
    static let reuseID = "MenuIconCell"

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: GlassTheme.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: GlassTheme.iconSize)
        ])

        contentView.applyGlassCard(cornerRadius: GlassTheme.itemRadius)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            contentView.backgroundColor = isSelected ? GlassTheme.selectedFill : GlassTheme.glassFill
        }
    }

    func render(item: DashboardMenuItem) {
        iconView.image = UIImage(systemName: item.symbolName)
        accessibilityLabel = item.title
    }
}
